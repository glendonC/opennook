// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import Combine
import NookSurface
import SwiftUI

/// The surface seam ``AppCoordinator`` drives.
///
/// `AppCoordinator` owns the notch chrome but should not be welded to the concrete
/// `Nook<AnyView, AnyView, AnyView>` generic specialization: a windowless test fake
/// cannot be a `Nook`, and the coordinator's logic — module switching, lifecycle
/// serialization, arbiter wiring — is what is worth testing without a real window.
///
/// This protocol is the abstraction. It captures exactly the surface API the
/// coordinator touches (verified against `AppCoordinator` and its extensions), and
/// nothing more. It lives in NookKit — *not* in NookSurface, which stays MIT and thin,
/// and *not* by widening `NookControllable`/`NookSurfacePresenting`. NookKit owns this
/// protocol, so conforming the MIT `Nook` to it via a retroactive `extension` here is
/// legal and leaves `Nook` itself untouched.
///
/// The `*Publisher` accessors bridge `Nook`'s `@Published` projections to type-erased
/// `AnyPublisher`s so the coordinator's Combine sinks bind against the protocol, not the
/// concrete type.
@MainActor
protocol NookSurfaceDriving: AnyObject {
    /// Current lifecycle state of the surface.
    var state: NookState { get }
    /// Emits on every distinct `state` transition.
    var statePublisher: AnyPublisher<NookState, Never> { get }

    /// `true` while the pointer is over the chrome.
    var isHovering: Bool { get }
    /// Emits on every `isHovering` change.
    var isHoveringPublisher: AnyPublisher<Bool, Never> { get }

    /// `true` while a file-drag session is over the chrome.
    var isDragInFlight: Bool { get }
    /// Emits on every `isDragInFlight` change.
    var isDragInFlightPublisher: AnyPublisher<Bool, Never> { get }

    /// Expand the chrome onto `screen` (or the resolved screen when `nil`).
    func expand(on screen: NSScreen?) async
    /// Collapse the chrome to its compact pill.
    func compact(on screen: NSScreen?) async
    /// Hide the chrome and tear its window down.
    func hide() async

    /// Lifecycle hooks projected onto the surface. Re-wired on a module switch.
    /// Explicitly `@MainActor`-isolated to match `Nook`'s contract — every observer
    /// touches main-actor state from these closures.
    var onExpand: (@MainActor () -> Void)? { get set }
    var onCompact: (@MainActor () -> Void)? { get set }
    var onHide: (@MainActor () -> Void)? { get set }
    var onFileDrop: (@MainActor ([URL]) -> Bool)? { get set }

    /// Resolves the screen the chrome should occupy when none is passed explicitly.
    var screenProvider: (@MainActor () -> NSScreen?)? { get set }

    /// Suspends auto-compact-on-hover-exit while `true`.
    var staysExpandedOnHoverExit: Bool { get set }

    /// How the chrome presents itself — notch-fused, floating, or auto.
    var presentation: NookPresentation { get set }

    /// Pins the chrome window's `NSAppearance`. `nil` follows the system.
    var chromeAppearance: NSAppearance? { get set }

    /// What the chrome paints behind compact and expanded content.
    var backdrop: NookBackdrop { get set }

    /// Open/close/conversion animation curves.
    var transitionConfiguration: NookTransitionConfiguration { get set }

    /// The chrome's window controller, or `nil` while hidden.
    var windowController: NSWindowController? { get }

    /// Play a one-shot peripheral cue along the chrome perimeter.
    func playFeedback(_ effect: NookFeedback, tint: Color, duration: TimeInterval, repeats: Bool)
}

extension NookSurfaceDriving {
    /// Convenience matching `Nook.playFeedback`'s defaulted call shape, so call sites
    /// such as `surface.playFeedback(.shimmer, duration: 1.1)` keep compiling.
    func playFeedback(
        _ effect: NookFeedback = .shimmer,
        tint: Color = Color(nsColor: .controlAccentColor),
        duration: TimeInterval = 0.85,
        repeats: Bool = false
    ) {
        playFeedback(effect, tint: tint, duration: duration, repeats: repeats)
    }
}

// MARK: - Nook conformance

/// Conforms the concrete (MIT) `Nook` to the NookKit-owned surface seam. NookKit owns
/// `NookSurfaceDriving`, so this retroactive conformance is legal and leaves `Nook`
/// untouched. The `*Publisher` accessors erase `Nook`'s `@Published` projections.
extension Nook: NookSurfaceDriving {
    var statePublisher: AnyPublisher<NookState, Never> {
        $state.eraseToAnyPublisher()
    }

    var isHoveringPublisher: AnyPublisher<Bool, Never> {
        $isHovering.eraseToAnyPublisher()
    }

    var isDragInFlightPublisher: AnyPublisher<Bool, Never> {
        $isDragInFlight.eraseToAnyPublisher()
    }
}
