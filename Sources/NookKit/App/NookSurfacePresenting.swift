// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Combine

/// How urgent a transient surface claim is. The arbiter grants a contended surface to
/// the highest priority, and uses `urgent` as the bar a background module's claim must
/// clear to reach the surface at all.
public enum NookSurfacePriority: Int, Comparable, Sendable {
    /// Low-stakes background cue — a volume HUD, an ambient indicator.
    case ambient
    /// An ordinary activity from the foreground module.
    case normal
    /// Time-sensitive. The only priority a background (non-foreground) module's claim
    /// is allowed to take the surface with.
    case urgent

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A request to take over the surface transiently, carrying the identity needed to
/// arbitrate it: which module is asking, and how urgently.
public struct NookSurfaceClaim: Sendable {
    /// The id of the module the claim is made on behalf of. When this is not the
    /// foreground module, the claim is granted only if its priority is `.urgent`.
    public let moduleID: String

    /// How the claim ranks against a competing one already holding the surface.
    public let priority: NookSurfacePriority

    public init(moduleID: String, priority: NookSurfacePriority = .normal) {
        self.moduleID = moduleID
        self.priority = priority
    }
}

/// Opaque handle to a granted transient presentation. A presenter holds the token it
/// got from ``NookSurfacePresenting/beginTransientPresentation(_:)`` and passes it back
/// to ``NookSurfacePresenting/endTransientPresentation(_:)`` to release the claim.
///
/// The wrapped value carries no meaning to a presenter — it only needs to round-trip
/// the token unchanged. The initializer is public so a conformer (including a test
/// fake) can mint tokens.
public struct NookSurfaceToken: Hashable, Sendable {
    public let value: Int

    public init(value: Int) {
        self.value = value
    }
}

/// Coordinated, arbitrated access to the notch surface for *transient* presenters.
///
/// A transient presenter — e.g. `NookComponents`' activity queue — briefly takes over
/// the expanded surface, then yields it back. It must not fight the user: while the
/// user is engaging the surface (hovering it, or having opened it themselves) a
/// transient presenter is denied.
///
/// `AppCoordinator` is the conformer; it owns the surface and arbitrates through a
/// `SurfaceArbiter`. The protocol keeps transient presenters decoupled from
/// `AppCoordinator`/`Nook` internals and lets them be unit-tested against a fake
/// conformer — no real window required.
@MainActor
public protocol NookSurfacePresenting: AnyObject {
    /// `true` while the user is actively engaging the surface — hovering it, or it is
    /// open because they opened it. A transient presenter is denied while this holds.
    var isUserEngaged: Bool { get }

    /// Emits whenever ``isUserEngaged`` changes.
    var userEngagementChanges: AnyPublisher<Bool, Never> { get }

    /// The id of the foreground module. A claim whose `moduleID` differs from this is
    /// gated — granted only when its priority is `.urgent`.
    var activeModuleID: String { get }

    /// Request the surface for a transient presentation. Returns a token when the claim
    /// is granted, `nil` when it is denied — because the user is engaging the surface,
    /// because a claim of equal or higher priority already holds it, or because it is a
    /// background module's non-urgent claim. A presenter that is denied should re-queue
    /// and retry rather than render as if it owns the surface.
    func beginTransientPresentation(_ claim: NookSurfaceClaim) async -> NookSurfaceToken?

    /// Release a granted claim. When it was the last claim outstanding the surface
    /// restores to the state captured before the first claim took it — unless the user
    /// has since engaged the surface, in which case their state is left untouched.
    func endTransientPresentation(_ token: NookSurfaceToken) async
}
