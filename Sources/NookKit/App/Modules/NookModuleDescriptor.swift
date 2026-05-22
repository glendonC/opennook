// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// The cheap, registration-time identity of a notch module — everything the host and
/// the module switcher need *before* the module itself is instantiated.
///
/// A ``NookModule`` carries product state and views; a descriptor carries only the
/// metadata to list it, key its persistence, and route a hotkey to it. The split keeps
/// registration free of side effects: a host can register a dozen modules and pay the
/// construction cost only for the ones the user actually opens.
public struct NookModuleDescriptor: Identifiable {
    /// Stable, unique identifier — reverse-DNS by convention (`"com.you.nuggie"`).
    /// Used as the switcher key, the per-module `UserDefaults` suite name, and the
    /// on-disk container folder name, so it must not change across releases.
    public let id: String

    /// Human-readable name shown in the module switcher.
    public var displayName: String

    /// SF Symbol shown for this module in the switcher and the top-bar cluster.
    public var icon: String

    /// Accent used to tint the module's switcher entry.
    public var accent: Color

    /// Optional global hotkey that jumps straight to this module. `nil` — the default —
    /// means the module is reachable only via the switcher or the cycle hotkey.
    public var hotkey: NookHotkey?

    /// What happens to the module when the user switches away from it.
    public var backgroundPolicy: BackgroundPolicy

    /// Residency policy for a module that is not the foreground module.
    public enum BackgroundPolicy {
        /// Tear the module down on switch-away; rebuild it on next activation. Cheapest;
        /// the module does no background work and posts no background activities.
        case unloadOnSwitchAway

        /// Keep the module instance alive in the background so its services and
        /// activity queue keep running. It can still post activities — the
        /// `SurfaceArbiter` gates whether a background module reaches the surface.
        case stayResident
    }

    public init(
        id: String,
        displayName: String,
        icon: String = "square.grid.2x2",
        accent: Color = .accentColor,
        hotkey: NookHotkey? = nil,
        backgroundPolicy: BackgroundPolicy = .unloadOnSwitchAway
    ) {
        self.id = id
        self.displayName = displayName
        self.icon = icon
        self.accent = accent
        self.hotkey = hotkey
        self.backgroundPolicy = backgroundPolicy
    }
}
