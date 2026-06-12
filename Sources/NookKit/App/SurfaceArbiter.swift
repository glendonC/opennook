// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookSurface

/// Decides who gets the notch surface when more than one transient presenter wants it.
///
/// One host process can run several modules, each with its own activity queue and
/// ambient indicators, all of them transient presenters. The arbiter resolves the
/// contention with a stack of granted claims:
///
/// - A claim is granted only if it outranks whatever currently holds the surface, the
///   user is not engaging the surface, and - for a claim from a background module - its
///   priority is `.urgent`.
/// - A higher-priority claim preempts a lower one: it is pushed on top and shows
///   immediately. The preempted claim stays on the stack; when it ends it simply leaves
///   the stack without disturbing the surface.
/// - The surface restores to its pre-presentation state only when the *last* claim
///   ends, so a run of back-to-back or stacked claims never flickers home in between.
///
/// The arbiter is policy only. It owns no surface state machine: every expand/compact/
/// hide it performs is handed to `runSerial`, which threads it through
/// `AppCoordinator.enqueueLifecycle` - the one serial chain all surface transitions run
/// on. The arbiter never serializes anything itself.
@MainActor
final class SurfaceArbiter {
    private struct Entry {
        let token: NookSurfaceToken
        let claim: NookSurfaceClaim
    }

    /// Granted claims, oldest at the bottom. The top entry is the one on screen.
    private var stack: [Entry] = []

    /// Tokens for claims that are still live. A token is recorded here on grant and
    /// removed when its claim ends or is invalidated by a module switch. `end` treats a
    /// token absent from this set as stale and a guaranteed no-op.
    private var liveTokens: Set<NookSurfaceToken> = []

    /// The surface state captured before the first claim took the surface - what the
    /// surface restores to once the stack empties. `nil` while no claim is outstanding.
    private var baseRestoreState: NookState?

    /// Per-token wall-clock watchdog tasks. A granted claim with non-`nil`
    /// ``NookSurfaceClaim/maxDuration`` mints a task here that sleeps the duration and
    /// then re-enters ``end(_:)`` to synthetically release the claim. Cancelled (and
    /// removed) when the claim ends cleanly or is invalidated by a module switch, so
    /// a well-behaved presenter pays nothing.
    private var watchdogs: [NookSurfaceToken: Task<Void, Never>] = [:]

    private var nextToken = 0

    // Every callback is `@MainActor`-isolated: the arbiter is a `@MainActor` type and
    // its callers (the coordinator) hand it main-actor closures that touch main-actor
    // state (`surface`, `appState`). Annotating the closure types `@MainActor` keeps
    // those captures legal under strict concurrency without crossing actor boundaries.
    private let isUserEngaged: @MainActor () -> Bool
    private let activeModuleID: @MainActor () -> String
    private let currentState: @MainActor () -> NookState
    private let runSerial: @MainActor (@escaping @Sendable @MainActor () async -> Void) async -> Void
    private let expand: @MainActor () async -> Void
    private let compact: @MainActor () async -> Void
    private let hide: @MainActor () async -> Void

    init(
        isUserEngaged: @escaping @MainActor () -> Bool,
        activeModuleID: @escaping @MainActor () -> String,
        currentState: @escaping @MainActor () -> NookState,
        runSerial: @escaping @MainActor (@escaping @Sendable @MainActor () async -> Void) async -> Void,
        expand: @escaping @MainActor () async -> Void,
        compact: @escaping @MainActor () async -> Void,
        hide: @escaping @MainActor () async -> Void
    ) {
        self.isUserEngaged = isUserEngaged
        self.activeModuleID = activeModuleID
        self.currentState = currentState
        self.runSerial = runSerial
        self.expand = expand
        self.compact = compact
        self.hide = hide
    }

    /// `true` while at least one claim holds the surface.
    var isPresenting: Bool { !stack.isEmpty }

    /// The priority of the claim currently on screen, or `nil` when idle.
    var topPriority: NookSurfacePriority? { stack.last?.claim.priority }

    /// The set of module ids that currently hold at least one outstanding claim.
    var presentingModuleIDs: Set<String> { Set(stack.map { $0.claim.moduleID }) }

    /// Grants `claim` the surface when it outranks the current holder, the user is not
    /// engaging the surface, and a background module's claim is `.urgent`. The decision
    /// runs on the serial lifecycle chain, so it is made *after* any queued user-driven
    /// transition rather than at call time.
    func begin(_ claim: NookSurfaceClaim) async -> NookSurfaceToken? {
        var granted: NookSurfaceToken?
        await runSerial { [self] in
            // A background module reaches the surface only with an urgent claim.
            if claim.moduleID != activeModuleID(), claim.priority < .urgent { return }
            // The user owns the surface whenever they are engaging it.
            // `isUserEngaged()` reflects user intent + hover - NOT mirror surface
            // state - so the arbiter's own `expand()` below never trips this gate
            // on a subsequent preempting claim.
            if isUserEngaged() { return }
            // Only a strictly higher priority preempts the claim already on screen.
            if let top = stack.last, claim.priority <= top.claim.priority { return }

            if stack.isEmpty {
                baseRestoreState = currentState()
            }
            let token = NookSurfaceToken(value: nextToken)
            nextToken += 1
            stack.append(Entry(token: token, claim: claim))
            liveTokens.insert(token)
            armWatchdog(for: token, claim: claim)
            await expand()
            granted = token
        }
        return granted
    }

    /// Starts the wall-clock watchdog for a granted claim - a presenter that never
    /// calls `endTransientPresentation` (crashed, has a bug, leaked) is the worst case
    /// this guards against. Cleaning up here keeps the stack bounded and prevents the
    /// "every subsequent claim is denied because a phantom claim still holds the
    /// surface" failure mode.
    private func armWatchdog(for token: NookSurfaceToken, claim: NookSurfaceClaim) {
        guard let maxDuration = claim.maxDuration else { return }
        // `[weak self]` keeps the watchdog from extending the arbiter's lifetime; if
        // the coordinator goes away before the watchdog fires, the auto-release is
        // moot anyway.
        let moduleID = claim.moduleID
        watchdogs[token] = Task { [weak self] in
            // `Task.sleep` throws on cancellation; the typed-throws fold turns that
            // into a nil - `end`/`invalidateClaims` cancel the task on a clean exit,
            // and we silently return.
            guard (try? await Task.sleep(for: maxDuration)) != nil else { return }
            guard let self else { return }
            // Same logging idiom as `AppCoordinator.runWithTimeout`. The
            // synthetic `end` re-enters the serial chain just like a presenter-driven
            // end, so it cannot race other transitions.
            print("[OpenNook] SurfaceArbiter watchdog: claim from '\(moduleID)' " +
                "exceeded \(maxDuration); auto-releasing")
            await self.end(token)
        }
    }

    /// Cancels a granted claim's watchdog and forgets it. Called from the only two
    /// paths a token leaves `liveTokens`: a clean `end`, or `invalidateClaims` on a
    /// module switch.
    private func cancelWatchdog(for token: NookSurfaceToken) {
        watchdogs.removeValue(forKey: token)?.cancel()
    }

    /// Invalidates every outstanding claim owned by `moduleID` - used when that module
    /// is being switched away from. Its content is leaving the surface anyway, so the
    /// claims are dropped (not transferred, not frozen) and their tokens go stale.
    ///
    /// This is a synchronous, in-memory policy mutation: it does NOT restore the surface
    /// (the switch transaction owns surface state for the incoming module) and does NOT
    /// open its own `runSerial` - it is invoked from inside an already-open serial block.
    func invalidateClaims(ownedBy moduleID: String) {
        let dropped = stack.filter { $0.claim.moduleID == moduleID }
        guard !dropped.isEmpty else { return }
        for entry in dropped {
            liveTokens.remove(entry.token)
            cancelWatchdog(for: entry.token)
        }
        stack.removeAll { $0.claim.moduleID == moduleID }
        if stack.isEmpty {
            baseRestoreState = nil
        }
    }

    /// Releases the claim for `token`. When it was the last outstanding claim the
    /// surface restores to its pre-presentation state - unless the user has since
    /// engaged it, in which case their state is left as-is.
    ///
    /// A token whose module was switched away (or otherwise invalidated) is stale: it is
    /// no longer in `liveTokens`, and `end` is a guaranteed no-op for it. This prevents a
    /// torn-down module's drain loop from collapsing the surface under the incoming one.
    func end(_ token: NookSurfaceToken) async {
        await runSerial { [self] in
            guard liveTokens.remove(token) != nil else { return }
            cancelWatchdog(for: token)
            guard let index = stack.firstIndex(where: { $0.token == token }) else { return }
            stack.remove(at: index)
            // A surviving claim still holds the surface - leave it expanded.
            guard stack.isEmpty else { return }

            let restoreTo = baseRestoreState ?? .compact
            baseRestoreState = nil
            guard !isUserEngaged() else { return }
            switch restoreTo {
            case .compact: await compact()
            case .hidden: await hide()
            case .expanded: break
            }
        }
    }
}
