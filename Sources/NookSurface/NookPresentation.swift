// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin - OpenNook
//
// Part of the MIT-licensed NookSurface module.
// Module license: /LICENSE-MIT-NOOKSURFACE

import Foundation

/// How the Nook chrome presents itself relative to the screen.
///
/// A notch app's whole premise is the physical notch - but plenty of Macs don't have
/// one (a Mac mini/Studio on an external display, pre-2021 MacBooks, any desktop
/// display). ``floating`` is the fallback: instead of an eared shape fused to the
/// menu-bar notch, the chrome renders as a free-floating rounded panel just below the
/// menu bar.
///
/// - ``auto`` - notch layout on a notched display, floating layout otherwise. The
///   default, and the right choice for almost every app.
/// - ``notch`` - always the notch layout, even on a display with no notch (the
///   eared shape then hangs from the bare menu bar; mostly useful for testing).
/// - ``floating`` - always the floating layout, even on a notched display.
public enum NookPresentation: String, Codable, Sendable, CaseIterable, Equatable {
    case auto
    case notch
    case floating

    /// Resolve this presentation against a concrete screen: should the chrome use the
    /// floating layout there?
    public func isFloating(screenHasNotch: Bool) -> Bool {
        switch self {
        case .auto: return !screenHasNotch
        case .notch: return false
        case .floating: return true
        }
    }
}

/// The resolved layout the surface actually renders - the concrete outcome of a
/// ``NookPresentation`` against a specific screen. Internal: callers express intent
/// through ``NookPresentation``; the surface picks the form.
enum NookChromeForm: Equatable {
    /// Eared shape fused to the menu-bar notch.
    case notch
    /// Free-floating rounded panel below the menu bar.
    case floating
}
