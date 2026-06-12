// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Combine
import Foundation

/// Holds the notch surface expanded while a module presents transient AppKit UI
/// that lives outside the notch window: a `.popover`, `.sheet`, or `.alert`.
///
/// **The problem.** Those presentations open a separate AppKit panel. The pointer
/// moves into that panel, which is outside the notch window, so the surface's
/// hover-tracking sees "exited" and auto-compacts, taking the popover down with
/// it. The same window-bounds escape also drops both signals that feed
/// ``AppCoordinator/isUserEngaged`` to `false` (`userInitiatedOpen` is false for
/// a hover-opened nook; `surface.isHovering` flips false when the pointer leaves
/// the notch window), so a same-process module's `.urgent` arbiter claim can be
/// granted at the same moment and yank the surface from underneath the popover.
///
/// **The shape.** A module acquires a *pin* while the transient UI is up. While
/// any pin is outstanding the broker projects two things:
///
/// 1. ``AppCoordinator/setStaysExpandedOverride(_:)`` is held `true`, suppressing
///    the hover-exit auto-compact at `Nook.swift`'s ``Nook/updateHoverState(_:)``.
/// 2. ``AppCoordinator/isUserEngaged`` (and its ``AppCoordinator/userEngagementChanges``
///    publisher) report `true`, denying competing arbiter claims for the duration.
///
/// Pins are **ref-counted**. Two overlapping popovers each get their own handle;
/// the surface stays pinned until the last one releases. The coordinator only
/// sees the 0->1 and N->0 edges via ``pinChanges``.
///
/// **Lifecycle.** A handle releases on ``NookPresentationPinHandle/release()``
/// or on `deinit`, whichever comes first. Pair with a SwiftUI binding via
/// `View.nookKeepsExpanded(while:)` for the popover/sheet case; resolve the
/// broker through `\.appServices` for non-view contexts (long-running uploads,
/// coordinator-driven flows).
///
/// **Scope.** One broker instance is shared across every module in the host
/// process. ``AppServices`` is per-module, but the *surface* is app-global, so
/// module A pinning the surface must also block module B's competing arbiter
/// claim. The host builds the broker once in
/// ``NookHostConfiguration/makeRegistry()`` and ``NookModuleRegistry`` registers
/// it into every module's services as their contexts are constructed.
@MainActor
public final class NookPresentationPinning {
    /// Live pin identities. The surface is pinned while this is non-empty.
    private var activePins: Set<Int> = []

    /// Optional reasons, keyed by pin token. Used by ``activeReasons`` for
    /// debugging "why is the surface stuck open"; not part of ref-counting.
    private var reasonsByPin: [Int: StaticString] = [:]

    /// Monotonically increasing token assigned to each `pin()` so the broker
    /// keys by a stable identity that survives a handle's deinit (an
    /// `ObjectIdentifier` of the handle would not - its pointer becomes
    /// undefined after deallocation, and ARC can drop the handle on any thread).
    private var nextToken: Int = 0

    private let pinChangesSubject = CurrentValueSubject<Bool, Never>(false)

    public nonisolated init() {}

    /// Acquire a pin. While the returned handle is live the surface is held
    /// expanded and counts as user-engaged.
    ///
    /// `reason` is recorded for diagnostics (see ``activeReasons``) and otherwise
    /// has no behavioral effect. `StaticString` keeps the diagnostic path
    /// zero-allocation in the hot case.
    public func pin(reason: StaticString? = nil) -> NookPresentationPinHandle {
        nextToken &+= 1
        let token = nextToken
        let wasPinned = !activePins.isEmpty
        activePins.insert(token)
        if let reason { reasonsByPin[token] = reason }
        if !wasPinned { pinChangesSubject.send(true) }
        return NookPresentationPinHandle(broker: self, token: token)
    }

    /// `true` while any pin is outstanding. Coordinator reads this in
    /// ``AppCoordinator/isUserEngaged``.
    public var isPinned: Bool { !activePins.isEmpty }

    /// Edge-triggered publisher: emits `true` on 0->1, `false` on N->0. Backed
    /// by a `CurrentValueSubject` so a late subscriber gets the current value.
    public var pinChanges: AnyPublisher<Bool, Never> {
        pinChangesSubject.removeDuplicates().eraseToAnyPublisher()
    }

    /// Reasons attached to the currently outstanding pins, in token order.
    /// Diagnostic surface; do not rely on it for control flow.
    public var activeReasons: [StaticString] {
        activePins.sorted().compactMap { reasonsByPin[$0] }
    }

    /// Releases the pin associated with `token`. Called by
    /// ``NookPresentationPinHandle`` on `release()` or `deinit`. Idempotent:
    /// a token that has already been released (or was never live) is a no-op.
    func release(token: Int) {
        guard activePins.remove(token) != nil else { return }
        reasonsByPin.removeValue(forKey: token)
        if activePins.isEmpty { pinChangesSubject.send(false) }
    }
}

/// Opaque RAII handle returned by ``NookPresentationPinning/pin(reason:)``.
///
/// The pin is released when the handle's owner calls ``release()`` or when the
/// handle is deinitialized, whichever comes first. The double-path matters: a
/// view modifier holds the handle in `@State` and calls ``release()`` on
/// `onChange(of:)` / `onDisappear` for prompt release; a non-view caller can
/// rely on the deinit fallback when the handle is dropped without an explicit
/// release.
@MainActor
public final class NookPresentationPinHandle {
    private weak var broker: NookPresentationPinning?
    private let token: Int
    private var released = false

    init(broker: NookPresentationPinning, token: Int) {
        self.broker = broker
        self.token = token
    }

    /// Release the pin. Idempotent; a second call is a no-op.
    public func release() {
        guard !released else { return }
        released = true
        broker?.release(token: token)
    }

    deinit {
        // Safety net for "non-view caller dropped the handle without calling
        // release()". ARC may run `deinit` on any thread, so the release is
        // dispatched to the main actor (the broker is `@MainActor`-isolated).
        // Idempotency in `NookPresentationPinning.release(token:)` makes a
        // race with a concurrent explicit `release()` safe.
        guard !released, let broker else { return }
        let capturedToken = token
        Task { @MainActor in
            broker.release(token: capturedToken)
        }
    }
}

/// Service key for resolving the host's shared ``NookPresentationPinning`` from
/// a module's ``AppServices``. The broker is wired in by
/// ``NookModuleContext`` at module construction; the default value is a
/// detached instance so resolving the key in tests or in a context that never
/// went through the registry returns something usable rather than crashing.
public struct NookPresentationPinningKey: ServiceKey {
    public static let defaultValue: NookPresentationPinning = NookPresentationPinning()
}
