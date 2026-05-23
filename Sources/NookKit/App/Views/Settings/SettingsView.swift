// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import SwiftUI

/// Top-level Settings surface, rendered when the expanded nook is in `.settings` mode.
/// Composes the per-section panels (Appearance, Shortcut & nook, Data, About) into
/// one scrolling stack. Each section panel is its own file under `Views/Settings/`.
struct SettingsView: View {
    @ObservedObject var appState: AppState
    let onToggleKeepOpen: () -> Void
    let onResetAllSettings: () -> Void

    @Environment(\.nookResolvedTheme) private var theme

    /// Caps Settings height from the main display so rows scroll instead of clipping below the notch panel.
    private var settingsScrollMaxHeight: CGFloat {
        guard let screen = NSScreen.main else {
            return 340
        }

        let visibleHeight = screen.visibleFrame.height
        return min(440, max(260, visibleHeight * 0.36))
    }

    private var chromeInteractionAccent: Color {
        Color(nsColor: .controlAccentColor)
    }

    /// Flip the haptic preference and fire one pulse on the way *on* so the user feels
    /// what they just enabled. Off doesn't pulse — silence is its whole point.
    private func toggleHapticFeedback() {
        var prefs = appState.appearancePreferences
        prefs.hapticFeedbackEnabled.toggle()
        appState.replaceAppearancePreferences(prefs)
        NookHaptics.confirm(enabled: prefs.hapticFeedbackEnabled)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsSectionLabel("Appearance")
                SettingsGroupedPanel {
                    AppearanceSettingsSection(appState: appState)
                }

                SettingsSectionLabel("Display")
                SettingsGroupedPanel {
                    DisplaySettingsSection(appState: appState)
                }

                SettingsSectionLabel("Shortcut & nook")
                SettingsGroupedPanel {
                    VStack(spacing: 0) {
                        SettingsShortcutRow(appState: appState)
                        if !appState.hotkeyRegistrationFailures.keys.filter({ $0 != NookHotkeyIDs.toggle }).isEmpty {
                            SettingsInsetDivider()
                            SettingsHotkeyFailureRow(appState: appState)
                        }
                        SettingsInsetDivider()
                        SettingActionLine(
                            icon: appState.keepNookOpen ? "pin.fill" : "pin",
                            title: "Stay expanded",
                            detail: appState.keepNookOpen ? "On — nook stays open after hover ends" : "Off — closes when the pointer leaves",
                            accent: chromeInteractionAccent,
                            action: onToggleKeepOpen
                        )
                        SettingsInsetDivider()
                        SettingActionLine(
                            icon: appState.appearancePreferences.hapticFeedbackEnabled ? "hand.tap.fill" : "hand.tap",
                            title: "Haptic feedback",
                            detail: appState.appearancePreferences.hapticFeedbackEnabled
                                ? "On — trackpad pulse on confirmation"
                                : "Off — silent confirmation",
                            accent: chromeInteractionAccent,
                            action: toggleHapticFeedback
                        )
                    }
                }

                SettingsSectionLabel("Data")
                SettingsGroupedPanel {
                    SettingsDataCommandRow(
                        title: "Reset All Settings",
                        subtitle: "Theme, surface, layout, display, hotkey, stay expanded",
                        icon: "arrow.counterclockwise",
                        style: .standard,
                        action: onResetAllSettings
                    )
                }

                SettingsSectionLabel("About")
                SettingsGroupedPanel {
                    SettingsAboutCard()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: settingsScrollMaxHeight, alignment: .leading)
    }
}
