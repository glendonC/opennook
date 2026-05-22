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
///   user is not engaging the surface, and — for a claim from a background module — its
///   priority is `.urgent`.
/// - A higher-priority claim preempts a lower one: it is pushed on top and shows
///   immediately. The preempted claim stays on the stack; when it ends it simply leaves
///   the stack without disturbing the surface.
/// - The surface restores to its pre-presentation state only when the *last* claim
///   ends, so a run of back-to-back or stacked claims never flickers home in between.
///
/// The arbiter is policy only. It owns no surface state machine: every expand/compact/
/// hide it performs is handed to `runSerial`, which threads it through
/// `AppCoordinator.enqueueLifecycle` — the one serial chain all surface transitions run
/// on. The arbiter never serializes anything itself.
@MainActor
final class SurfaceArbiter {
    private struct Entry {
        let token: NookSurfaceToken
        let claim: NookSurfaceClaim
    }

    /// Granted claims, oldest at the bottom. The top entry is the one on screen.
    private var stack: [Entry] = []

    /// The surface state captured before the first claim took the surface — what the
    /// surface restores to once the stack empties. `nil` while no claim is outstanding.
    private var baseRestoreState: NookState?

    private var nextToken = 0

    private let isUserEngaged: () -> Bool
    private let activeModuleID: () -> String
    private let currentState: () -> NookState
    private let runSerial: (@escaping @MainActor () async -> Void) async -> Void
    private let expand: () async -> Void
    private let compact: () async -> Void
    private let hide: () async -> Void

    init(
        isUserEngaged: @escaping () -> Bool,
        activeModuleID: @escaping () -> String,
        currentState: @escaping () -> NookState,
        runSerial: @escaping (@escaping @MainActor () async -> Void) async -> Void,
        expand: @escaping () async -> Void,
        compact: @escaping () async -> Void,
        hide: @escaping () async -> Void
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
            if isUserEngaged() { return }
            // Only a strictly higher priority preempts the claim already on screen.
            if let top = stack.last, claim.priority <= top.claim.priority { return }

            if stack.isEmpty {
                baseRestoreState = currentState()
            }
            let token = NookSurfaceToken(value: nextToken)
            nextToken += 1
            stack.append(Entry(token: token, claim: claim))
            await expand()
            granted = token
        }
        return granted
    }

    /// Releases the claim for `token`. When it was the last outstanding claim the
    /// surface restores to its pre-presentation state — unless the user has since
    /// engaged it, in which case their state is left as-is.
    func end(_ token: NookSurfaceToken) async {
        await runSerial { [self] in
            guard let index = stack.firstIndex(where: { $0.token == token }) else { return }
            stack.remove(at: index)
            // A surviving claim still holds the surface — leave it expanded.
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
