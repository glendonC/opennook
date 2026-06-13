// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// Which display the Nook chrome should appear on.
///
/// A notch app's chrome is physically tied to a screen, but on a multi-display Mac
/// "which screen" is a real choice. This expresses that choice in a form that
/// survives reboots and display reconfiguration:
///
/// - ``Mode/builtIn`` - the laptop's built-in (notched) panel. The default: a notch
///   app's chrome belongs where the physical notch is.
/// - ``Mode/main`` - whichever display currently hosts the active menu bar
///   (`NSScreen.main`). Follows the user's focus across screens.
/// - ``Mode/specific`` - a single named display, pinned by its stable display UUID
///   (``displayUUID``). Survives unplug/replug and arrangement changes.
///
/// Resolving a preference to a concrete `NSScreen` is ``NookScreenLocator``'s job;
/// it falls back gracefully when the chosen display isn't currently attached.
public struct NookDisplayPreference: Equatable, Codable, Sendable {
    public enum Mode: String, Codable, Sendable, CaseIterable {
        case builtIn
        case main
        case specific
    }

    public var mode: Mode

    /// Stable display UUID, used only when ``mode`` is ``Mode/specific``. `nil` for the
    /// built-in / main modes. The UUID comes from `CGDisplayCreateUUIDFromDisplayID`
    /// and is stable across reconnects, unlike the transient `CGDirectDisplayID`.
    public var displayUUID: String?

    public init(mode: Mode, displayUUID: String? = nil) {
        self.mode = mode
        self.displayUUID = displayUUID
    }

    /// The built-in (notched) display. A notch app's chrome belongs on the notch.
    public static let builtIn = NookDisplayPreference(mode: .builtIn)

    /// The display currently hosting the active menu bar (`NSScreen.main`).
    public static let main = NookDisplayPreference(mode: .main)

    /// A single display pinned by its stable display UUID.
    public static func specific(_ uuid: String) -> NookDisplayPreference {
        NookDisplayPreference(mode: .specific, displayUUID: uuid)
    }

    public static let `default` = NookDisplayPreference.builtIn

    private enum CodingKeys: String, CodingKey {
        case mode
        case displayUUID
    }

    // Lenient decode so JSON from an older/newer build round-trips to a sane value
    // instead of failing the whole record. An unrecognized `mode` string, or a
    // `.specific` mode missing its UUID, both degrade to the default rather than throw.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawMode = try container.decodeIfPresent(String.self, forKey: .mode)
        let uuid = try container.decodeIfPresent(String.self, forKey: .displayUUID)
        guard let rawMode, let mode = Mode(rawValue: rawMode) else {
            self = .default
            return
        }
        if mode == .specific, uuid == nil {
            self = .default
            return
        }
        self.init(mode: mode, displayUUID: uuid)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(displayUUID, forKey: .displayUUID)
    }
}

// MARK: - Persistence

/// UserDefaults-backed store for ``NookDisplayPreference``. Mirrors `NookHotkeyStore`.
enum NookDisplayStore {
    private static let defaultsKey = "opennook.display.v1"

    static func load() -> NookDisplayPreference {
        load(default: .default)
    }

    /// Loads the persisted value, falling back to `fallback` (rather than `.default`)
    /// when nothing is persisted or the record is unreadable. The fallback is the host's
    /// launch seed (see ``NookPreferenceDefaults``) and is never written here.
    static func load(default fallback: NookDisplayPreference) -> NookDisplayPreference {
        guard let data = NookPreferenceStorage.defaults.data(forKey: defaultsKey) else {
            return fallback
        }
        return (try? JSONDecoder().decode(NookDisplayPreference.self, from: data)) ?? fallback
    }

    static func save(_ preference: NookDisplayPreference) {
        if let data = try? JSONEncoder().encode(preference) {
            NookPreferenceStorage.defaults.set(data, forKey: defaultsKey)
        }
    }
}
