// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// Host-supplied *launch defaults* for the process-global preferences that otherwise
/// only have framework defaults until the user changes them in the Settings UI:
/// appearance (palette / surface style / presentation / haptics / keep-open), the
/// global show/hide ``NookHotkey``, and the ``NookDisplayPreference``.
///
/// These are **seed** values, not overrides. They replace the framework `.default`
/// fallback used when nothing is persisted yet - so a host can ship its own out-of-box
/// look (e.g. dark, translucent, floating, pinned-open) and shortcut without the user
/// having to open Settings first. The moment the user changes one of these at runtime
/// the change is persisted and always wins; a seed value is **never written** to
/// `UserDefaults`, so revising a default in a later build still reaches users who never
/// touched that setting.
///
/// Because there is a single ``AppState`` per process, these are host-process-global - 
/// set them on ``NookHostConfiguration/preferenceDefaults`` (multi-module) or, for the
/// single-module path, on ``NookConfiguration/preferenceDefaults`` (forwarded to the
/// synthesized host). The default value reproduces the framework exactly.
///
/// `Sendable`: assembled at a `main.swift`'s nonisolated top level and handed to
/// `NookApp.main`, which crosses to the main actor - like the configurations that carry
/// it.
public struct NookPreferenceDefaults: Sendable, Equatable {
    /// First-run appearance personalization. Defaults to ``NookAppearancePreferences/default``.
    public var appearance: NookAppearancePreferences

    /// First-run global show/hide shortcut. Defaults to ``NookHotkey/default`` (⌘⌥;).
    public var hotkey: NookHotkey

    /// First-run display target. Defaults to ``NookDisplayPreference/default`` (built-in).
    public var display: NookDisplayPreference

    public init(
        appearance: NookAppearancePreferences = .default,
        hotkey: NookHotkey = .default,
        display: NookDisplayPreference = .default
    ) {
        self.appearance = appearance
        self.hotkey = hotkey
        self.display = display
    }

    /// The framework defaults - what ships when a host sets no launch preferences. Using
    /// this reproduces today's behavior exactly.
    public static let `default` = NookPreferenceDefaults()
}
