// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation
import NookSurface
import SwiftUI

/// Persistent personalization for the Nook chrome - appearance (materials, palette),
/// layout, and chrome behavior that should survive across launches.
public struct NookAppearancePreferences: Equatable, Codable, Sendable {
    /// Follow the macOS appearance, or pin the chrome to dark / light.
    public var chromePalette: NookChromePalette

    /// Solid (opaque, matches the notch) or translucent (frosted, shows the wallpaper).
    public var surfaceStyle: NookSurfaceStyle

    /// Notch-fused or free-floating chrome - `.auto` follows the display. See
    /// ``NookPresentation``. This is what lets OpenNook work on a Mac with no notch.
    public var presentation: NookPresentation

    /// When on, completion-style events play a one-shot trackpad haptic via
    /// `NSHapticFeedbackManager`. Off by default - macOS haptics only fire when the user's
    /// hand is on a Force Touch trackpad with system haptics enabled, so this is a bonus
    /// completion signal, never the primary feedback channel.
    public var hapticFeedbackEnabled: Bool

    /// When on, the expanded nook stays open after the pointer leaves instead of
    /// auto-collapsing on hover-exit (the top-bar lock / Settings "stay expanded"
    /// toggle). Persisted so a pinned-open nook survives a relaunch.
    public var keepNookOpen: Bool

    /// Chrome control tint (lock, gear, toggles). `.system` follows macOS accent.
    public var accentPreset: NookAccentPreset

    /// Scales the frosted backdrop's legibility darken pass when ``surfaceStyle`` is
    /// `.translucent`. `1` is the framework default; lower values show more wallpaper.
    public var backdropStrength: Double

    public init(
        chromePalette: NookChromePalette = .followSystem,
        surfaceStyle: NookSurfaceStyle = .solid,
        presentation: NookPresentation = .auto,
        hapticFeedbackEnabled: Bool = false,
        keepNookOpen: Bool = false,
        accentPreset: NookAccentPreset = .system,
        backdropStrength: Double = 1
    ) {
        self.chromePalette = chromePalette
        self.surfaceStyle = surfaceStyle
        self.presentation = presentation
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.keepNookOpen = keepNookOpen
        self.accentPreset = accentPreset
        self.backdropStrength = backdropStrength
    }

    /// Framework defaults - what `NookApp.main()` ships if the host has never written
    /// preferences.
    public static let `default` = NookAppearancePreferences()

    private enum CodingKeys: String, CodingKey {
        case chromePalette
        case surfaceStyle
        case presentation
        case hapticFeedbackEnabled
        case keepNookOpen
        case accentPreset
        case backdropStrength
    }

    // Custom decode so JSON written by an older build (missing a later-added field)
    // round-trips to the current defaults instead of failing the whole record back to
    // `.default` and wiping the user's saved preferences. To add a field: give it a
    // default in the initializer and a matching `decodeIfPresent` line here.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.chromePalette =
            try container.decodeIfPresent(NookChromePalette.self, forKey: .chromePalette) ?? .followSystem
        self.surfaceStyle = try container.decodeIfPresent(NookSurfaceStyle.self, forKey: .surfaceStyle) ?? .solid
        self.presentation = try container.decodeIfPresent(NookPresentation.self, forKey: .presentation) ?? .auto
        self.hapticFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticFeedbackEnabled) ?? false
        self.keepNookOpen = try container.decodeIfPresent(Bool.self, forKey: .keepNookOpen) ?? false
        self.accentPreset = try container.decodeIfPresent(NookAccentPreset.self, forKey: .accentPreset) ?? .system
        self.backdropStrength = try container.decodeIfPresent(Double.self, forKey: .backdropStrength) ?? 1
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(chromePalette, forKey: .chromePalette)
        try container.encode(surfaceStyle, forKey: .surfaceStyle)
        try container.encode(presentation, forKey: .presentation)
        try container.encode(hapticFeedbackEnabled, forKey: .hapticFeedbackEnabled)
        try container.encode(keepNookOpen, forKey: .keepNookOpen)
        try container.encode(accentPreset, forKey: .accentPreset)
        try container.encode(backdropStrength, forKey: .backdropStrength)
    }
}

/// Pins the chrome palette to follow macOS or to a fixed light/dark - independent of
/// the wallpaper-aware ``NookSurfaceStyle``.
public enum NookChromePalette: String, Codable, Sendable, CaseIterable {
    case followSystem
    case dark
    case light
}

/// `.solid` paints the chrome the same opaque color as the menu-bar notch - true black on
/// dark, true white on light - so the expanded panel reads as one continuous surface.
/// `.translucent` shows the wallpaper through a frosted material instead. `.liquidGlass`
/// renders Apple's Liquid Glass material (macOS 26+), with a layered approximation on
/// earlier systems; Reduce Transparency collapses both translucent styles to `.solid`.
public enum NookSurfaceStyle: String, Codable, Sendable, CaseIterable {
    case solid
    case translucent
    case liquidGlass
}

// MARK: - Persistence

enum NookAppearanceStore {
    private static let defaultsKey = "opennook.appearance.v1"

    static func load() -> NookAppearancePreferences {
        load(default: .default)
    }

    /// Loads the persisted value, falling back to `fallback` (rather than `.default`)
    /// when nothing is persisted or the record is unreadable. The fallback is the host's
    /// launch seed (see ``NookPreferenceDefaults``) and is never written here.
    static func load(default fallback: NookAppearancePreferences) -> NookAppearancePreferences {
        guard let data = NookPreferenceStorage.defaults.data(forKey: defaultsKey) else {
            return fallback
        }
        do {
            return try JSONDecoder().decode(NookAppearancePreferences.self, from: data)
        } catch {
            return fallback
        }
    }

    static func save(_ preferences: NookAppearancePreferences) {
        do {
            let data = try JSONEncoder().encode(preferences)
            NookPreferenceStorage.defaults.set(data, forKey: defaultsKey)
        } catch {
            // Best-effort persistence; ignore encode failures.
        }
    }
}
