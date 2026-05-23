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
@testable import NookKit

/// A windowless ``NookSurfaceDriving`` stand-in for exercising ``AppCoordinator``
/// without a real `Nook` (no `NSWindow`, no animation timing).
///
/// State and the observable streams are backed by `CurrentValueSubject`s; lifecycle
/// transitions are applied synchronously, recorded in ``transitions``, and fire the
/// `on*` hooks just as the real surface does on each state change.
@MainActor
final class FakeNookSurface: NookSurfaceDriving {
    /// Every state this surface has transitioned *into*, in order. The constructor's
    /// initial `.hidden` is not recorded — only transitions driven by the coordinator.
    private(set) var transitions: [NookState] = []

    private let stateSubject = CurrentValueSubject<NookState, Never>(.hidden)
    private let hoveringSubject = CurrentValueSubject<Bool, Never>(false)
    private let dragSubject = CurrentValueSubject<Bool, Never>(false)

    var state: NookState { stateSubject.value }
    var statePublisher: AnyPublisher<NookState, Never> {
        stateSubject.removeDuplicates().eraseToAnyPublisher()
    }

    var isHovering: Bool {
        get { hoveringSubject.value }
        set { hoveringSubject.send(newValue) }
    }
    var isHoveringPublisher: AnyPublisher<Bool, Never> {
        hoveringSubject.removeDuplicates().eraseToAnyPublisher()
    }

    var isDragInFlight: Bool {
        get { dragSubject.value }
        set { dragSubject.send(newValue) }
    }
    var isDragInFlightPublisher: AnyPublisher<Bool, Never> {
        dragSubject.removeDuplicates().eraseToAnyPublisher()
    }

    var onExpand: (@MainActor () -> Void)?
    var onCompact: (@MainActor () -> Void)?
    var onHide: (@MainActor () -> Void)?
    var onFileDrop: (@MainActor ([URL]) -> Bool)?
    var screenProvider: (@MainActor () -> NSScreen?)?
    var staysExpandedOnHoverExit: Bool = false
    var presentation: NookPresentation = .auto
    var chromeAppearance: NSAppearance?
    var backdrop: NookBackdrop = .solidBlack
    var transitionConfiguration = NookTransitionConfiguration()
    var windowController: NSWindowController?

    /// Records every `playFeedback` request.
    private(set) var feedbackCount = 0

    func expand(on screen: NSScreen?) async { transition(to: .expanded) }
    func compact(on screen: NSScreen?) async { transition(to: .compact) }
    func hide() async { transition(to: .hidden) }

    func playFeedback(_ effect: NookFeedback, tint: Color, duration: TimeInterval, repeats: Bool) {
        feedbackCount += 1
    }

    /// Applies a state change, records it, and fires the matching lifecycle hook —
    /// mirroring the real surface, whose hooks fire on every distinct transition.
    private func transition(to newState: NookState) {
        guard newState != stateSubject.value else { return }
        stateSubject.send(newState)
        transitions.append(newState)
        switch newState {
        case .expanded: onExpand?()
        case .compact: onCompact?()
        case .hidden: onHide?()
        }
    }
}
