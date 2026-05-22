// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the MIT License.
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import AppKit

/// Handler the panel calls when a system drag session enters / exits / drops on its window.
///
/// `NookPanel` covers the full top half of the screen (because the panel itself is the
/// drag-receiving region — the visible notch silhouette is just a clip mask), so any
/// file drag aimed even loosely at the menu-bar area lands here. The chrome is the
/// SwiftUI surface; the panel just relays drag-session lifecycle calls into the `Nook`
/// that owns it.
///
/// `@MainActor` — AppKit delivers drag-session callbacks on the main thread, and the
/// conformer (`Nook`) is main-actor-isolated.
@MainActor
protocol NookDragDestination: AnyObject {
    /// Drag entered the panel's bounds. Return the operation we want to advertise to
    /// the dragging source (`.copy` registers the green "+" badge users expect).
    func nookPanelDraggingEntered(_ urls: [URL]) -> NSDragOperation

    /// Drag left without dropping — restore prior state.
    func nookPanelDraggingExited()

    /// Drop landed. Returning `true` tells AppKit the drop was accepted.
    func nookPanelPerformDrop(_ urls: [URL]) -> Bool
}
