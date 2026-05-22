// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Combine
import Foundation
import NookKit

/// A priority queue of transient notch activities.
///
/// Enqueue ``NookActivity`` values; the queue drains them one at a time, highest
/// ``NookActivityPriority/high`` first, collapsing any that share a `coalescingKey`.
/// Presenting an activity briefly takes over the expanded surface through a
/// ``NookSurfacePresenting`` — typically `AppCoordinator`, supplied via
/// `NookConfiguration.onReady`:
///
/// ```swift
/// let queue = NookActivityQueue()
/// configuration.onReady = { queue.bind(to: $0) }
/// // …later, from anywhere on the main actor:
/// queue.enqueue(NookActivity(title: "Build finished", systemImage: "hammer"))
/// ```
///
/// The queue **yields to the user**: while the user is hovering or has opened the nook
/// themselves it pauses, resuming once they disengage. It does not preempt an activity
/// that is already on screen — priority orders only what is still pending.
@MainActor
public final class NookActivityQueue: ObservableObject {
    /// The activity currently on screen, or `nil`. A host view (see ``NookActivityHost``)
    /// renders this.
    @Published public private(set) var current: NookActivity?

    /// Activities waiting to be presented, in enqueue order.
    @Published public private(set) var pending: [NookActivity] = []

    /// `true` while draining is suspended via ``suspend()``.
    @Published public private(set) var isSuspended: Bool = false

    private weak var presenter: (any NookSurfacePresenting)?

    /// The module this queue presents on behalf of — stamped onto every surface claim so
    /// the arbiter can gate a background module's activities. Captured at ``bind(to:moduleID:)``.
    private var moduleID = ""

    /// The running drain loop, or `nil` when idle. Internal so tests can await it.
    var drainTask: Task<Void, Never>?

    /// Injectable sleep — real time in production, instant in tests.
    private let sleep: @Sendable (Duration) async -> Void

    /// - Parameter sleep: how the queue waits out an activity's `dwell`. Defaults to a
    ///   real `Task.sleep`; tests pass an instant closure to drive timing deterministically.
    public init(sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    /// Connects the queue to the surface it presents through, and starts draining any
    /// already-queued activities. Call once — `NookConfiguration.onReady` is the seam.
    ///
    /// - Parameter moduleID: the module this queue belongs to, stamped onto its surface
    ///   claims. When `nil`, the foreground module at bind time is assumed — correct for
    ///   a single-module host. A multi-module host should pass `context.descriptor.id`
    ///   so a backgrounded module's activities are gated correctly.
    public func bind(to presenter: any NookSurfacePresenting, moduleID: String? = nil) {
        self.presenter = presenter
        self.moduleID = moduleID ?? presenter.activeModuleID
        startDrainingIfNeeded()
    }

    /// Adds an activity. If it carries a `coalescingKey`, any pending peer with the same
    /// key is dropped first (keep-latest).
    public func enqueue(_ activity: NookActivity) {
        if let key = activity.coalescingKey {
            pending.removeAll { $0.coalescingKey == key }
        }
        pending.append(activity)
        startDrainingIfNeeded()
    }

    /// Removes a still-pending activity. No effect once it is on screen.
    public func cancel(_ id: NookActivity.ID) {
        pending.removeAll { $0.id == id }
    }

    /// Removes all pending activities with the given coalescing key.
    public func cancelAll(coalescingKey: String) {
        pending.removeAll { $0.coalescingKey == coalescingKey }
    }

    /// Pauses draining. An activity already on screen finishes its dwell; nothing new is
    /// presented until ``resume()``.
    public func suspend() {
        guard !isSuspended else { return }
        isSuspended = true
        drainTask?.cancel()
        drainTask = nil
    }

    /// Resumes draining after ``suspend()``.
    public func resume() {
        guard isSuspended else { return }
        isSuspended = false
        startDrainingIfNeeded()
    }

    // MARK: - Drain loop

    private func startDrainingIfNeeded() {
        guard !isSuspended, drainTask == nil, presenter != nil, !pending.isEmpty else { return }
        drainTask = Task { [weak self] in
            await self?.drain()
            // Only a drain that finished *naturally* clears the handle. A cancelled
            // drain was detached by `suspend()`, which already niled the handle — and
            // a `resume()` may since have installed a fresh drain; don't clobber it.
            if !Task.isCancelled {
                self?.drainTask = nil
            }
        }
    }

    private func drain() async {
        while !isSuspended, !Task.isCancelled, let presenter, !pending.isEmpty {
            // Don't fight the user for the surface. Yield *before* claiming an
            // activity: it stays in `pending` until it is actually about to be
            // presented, so a `suspend()` or cancellation during the wait leaves it
            // queued for the next drain rather than stranding it in a discarded task.
            await waitWhileUserEngaged(presenter)
            if isSuspended || Task.isCancelled { break }
            guard let activity = dequeue() else { break }

            let claim = NookSurfaceClaim(moduleID: moduleID, priority: activity.priority.surfacePriority)
            guard let token = await presenter.beginTransientPresentation(claim) else {
                // Denied — the user grabbed the surface, or another presenter outranks
                // this claim. Put the activity back at the front and back off briefly so
                // a contended surface is retried without spinning.
                requeue(activity)
                do {
                    try await Task.sleep(for: Self.contentionBackoff)
                } catch {
                    break  // drain task cancelled (suspend / teardown)
                }
                continue
            }
            current = activity
            await sleep(activity.dwell)
            // Collapse the surface *before* clearing `current`, so the host renders the
            // activity card through the collapse rather than flashing idle home content.
            await presenter.endTransientPresentation(token)
            current = nil
        }
    }

    /// Returns an activity to the front of the pending queue after a rejected takeover.
    /// Front insertion preserves FIFO order against same-priority peers on the retry.
    private func requeue(_ activity: NookActivity) {
        pending.insert(activity, at: 0)
    }

    /// Removes and returns the highest-priority pending activity, FIFO within a priority.
    private func dequeue() -> NookActivity? {
        guard let maxPriority = pending.map(\.priority).max(),
              let index = pending.firstIndex(where: { $0.priority == maxPriority }) else {
            return nil
        }
        return pending.remove(at: index)
    }

    /// Suspends the drain loop while the user is engaging the surface, returning once
    /// they disengage — or promptly when the queue is suspended or the drain task is
    /// cancelled.
    ///
    /// This polls rather than awaiting `userEngagementChanges` directly. That publisher
    /// collapses duplicates, so a `for await` over it parks until the *next distinct*
    /// value arrives — and a `suspend()`/teardown that cancels the drain task while the
    /// user stays engaged would never wake it. `Task.sleep` throws `CancellationError`
    /// the instant the task is cancelled, so the wait can never outlive its task.
    private func waitWhileUserEngaged(_ presenter: any NookSurfacePresenting) async {
        while presenter.isUserEngaged, !isSuspended {
            do {
                try await Task.sleep(for: Self.engagementPollInterval)
            } catch {
                return  // drain task cancelled (suspend / teardown)
            }
        }
    }

    /// How often ``waitWhileUserEngaged(_:)`` re-checks engagement. Short enough that a
    /// disengaged user sees the next activity without a perceptible gap; only ticks
    /// while the user is actively engaging the surface.
    private static let engagementPollInterval: Duration = .milliseconds(200)

    /// How long the drain loop waits after a denied takeover before retrying. Keeps a
    /// surface contended by another presenter from spinning the loop.
    private static let contentionBackoff: Duration = .milliseconds(150)
}

private extension NookActivityPriority {
    /// Maps an activity's queue priority onto the surface-claim priority the arbiter
    /// ranks contending presenters by.
    var surfacePriority: NookSurfacePriority {
        switch self {
        case .low: return .ambient
        case .normal: return .normal
        case .high: return .urgent
        }
    }
}
