// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import CoreGraphics

/// Resolves a ``NookDisplayPreference`` to a concrete `NSScreen`, and enumerates the
/// attached displays for settings UI.
///
/// The tricky part of multi-display support is *stable* identity: `CGDirectDisplayID`
/// and `NSScreen` ordering both shuffle as displays connect and disconnect, so a saved
/// preference can't reference them directly. The display *UUID*
/// (`CGDisplayCreateUUIDFromDisplayID`) is stable across reconnects, so that's what
/// ``NookDisplayPreference/specific(_:)`` persists and what this type matches against.
public enum NookScreenLocator {
    /// A currently-attached display, as surfaced to settings UI.
    public struct DisplayInfo: Identifiable, Equatable, Sendable {
        /// Stable display UUID - the value stored in ``NookDisplayPreference``.
        public let uuid: String
        /// Human-readable name (`NSScreen.localizedName`), e.g. "Built-in Retina Display".
        public let name: String
        /// `true` for the Mac's built-in panel.
        public let isBuiltIn: Bool

        public var id: String { uuid }
    }

    /// The `CGDirectDisplayID` backing a screen. Transient - valid only for the current
    /// display arrangement; never persist it.
    public static func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    /// Stable UUID string for a display ID, surviving unplug/replug. `nil` for the rare
    /// display that exposes no UUID (some virtual/streamed displays).
    public static func uuid(for displayID: CGDirectDisplayID) -> String? {
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return nil
        }
        return CFUUIDCreateString(nil, cfUUID) as String
    }

    /// Stable UUID string for a screen.
    public static func uuid(for screen: NSScreen) -> String? {
        guard let id = displayID(for: screen) else { return nil }
        return uuid(for: id)
    }

    /// Every currently-attached display, for populating a display picker.
    public static func connectedDisplays() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let id = displayID(for: screen), let uuid = uuid(for: id) else { return nil }
            return DisplayInfo(
                uuid: uuid,
                name: screen.localizedName,
                isBuiltIn: CGDisplayIsBuiltin(id) != 0
            )
        }
    }

    /// A display abstracted to just what the fallback chain needs, so the resolution
    /// *policy* can be unit-tested without a live `NSScreen` (which is unavailable on
    /// headless CI). The AppKit path builds these from `NSScreen.screens`.
    public struct DisplayCandidate: Equatable, Sendable {
        /// Stable display UUID, or `nil` for displays that expose none.
        public let uuid: String?
        /// `true` for the Mac's built-in panel.
        public let isBuiltIn: Bool

        public init(uuid: String?, isBuiltIn: Bool) {
            self.uuid = uuid
            self.isBuiltIn = isBuiltIn
        }
    }

    /// Pure fallback-chain policy: pick the index into `displays` that satisfies
    /// `preference`, degrading rather than vanishing when the chosen display is gone.
    ///
    /// - `.specific`: the matching UUID, else built-in -> main -> first.
    /// - `.builtIn`: built-in -> main -> first.
    /// - `.main`: main -> built-in -> first.
    ///
    /// Returns `nil` only when `displays` is empty. `mainIndex` is the index of the
    /// system's main display within `displays` (the AppKit path derives it from
    /// `NSScreen.main`); `nil` if unknown.
    public static func resolveIndex(
        preference: NookDisplayPreference,
        displays: [DisplayCandidate],
        mainIndex: Int?
    ) -> Int? {
        guard !displays.isEmpty else { return nil }
        let builtInIndex = displays.firstIndex { $0.isBuiltIn }
        let builtInThenMainThenFirst = builtInIndex ?? mainIndex ?? 0

        switch preference.mode {
        case .specific:
            if let uuid = preference.displayUUID,
               let match = displays.firstIndex(where: { $0.uuid == uuid }) {
                return match
            }
            return builtInThenMainThenFirst
        case .builtIn:
            return builtInThenMainThenFirst
        case .main:
            return mainIndex ?? builtInIndex ?? 0
        }
    }

    /// Resolve a preference to a concrete screen.
    ///
    /// The fallback chain keeps the chrome on-screen even when the chosen display is
    /// unplugged: a `.specific` display that isn't attached, or a `.builtIn` request on a
    /// desktop Mac, both degrade to built-in -> main -> first-attached rather than vanishing.
    /// Returns `nil` only when no display is attached at all. The policy lives in
    /// ``resolveIndex(preference:displays:mainIndex:)`` so it stays testable headlessly.
    public static func screen(matching preference: NookDisplayPreference) -> NSScreen? {
        let screens = NSScreen.screens
        let candidates = screens.map { DisplayCandidate(uuid: Self.uuid(for: $0), isBuiltIn: isBuiltIn($0)) }
        let mainIndex = NSScreen.main.flatMap { screens.firstIndex(of: $0) }
        guard let index = resolveIndex(preference: preference, displays: candidates, mainIndex: mainIndex) else {
            return nil
        }
        return screens[index]
    }

    /// Whether a screen is the Mac's built-in panel.
    private static func isBuiltIn(_ screen: NSScreen) -> Bool {
        guard let id = displayID(for: screen) else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }

    /// The Mac's built-in panel, if one is attached.
    public static func builtInScreen() -> NSScreen? {
        NSScreen.screens.first(where: isBuiltIn)
    }
}
