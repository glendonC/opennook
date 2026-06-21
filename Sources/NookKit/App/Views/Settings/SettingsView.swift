// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import NookSurface
import SwiftUI

/// Top-level Settings surface, rendered when the expanded nook is in `.settings` mode.
/// Composes the per-section groups (Appearance, Display, Shortcut & nook, Data, About)
/// into one scrolling stack. Each section's content is its own file under `Views/Settings/`.
///
/// Layout is deliberately flat: section label, then content, on one shared left margin
/// (aligned with the top bar via `\.nookContentInsets`), separated by whitespace only - 
/// no card fills, no rules.
struct SettingsView: View {
    @ObservedObject var appState: AppState
    let onToggleKeepOpen: () -> Void
    let onResetAllSettings: () -> Void

    @Environment(\.nookResolvedTheme) private var theme

    /// Curve-derived leading/trailing insets from the chrome. Matching them here aligns the
    /// section labels and rows with the top bar's leading cluster on a notched display.
    @Environment(\.nookContentInsets) private var contentInsets

    /// Which sections are expanded. In-memory for the session; Appearance opens by default
    /// so the surface isn't a wall of collapsed headers on first entry.
    @State private var expandedSections: Set<String> = ["Appearance"]

    /// Caps Settings height from the main display so rows scroll instead of clipping below the notch panel.
    private var settingsScrollMaxHeight: CGFloat {
        guard let screen = NSScreen.main else {
            return 340
        }

        let visibleHeight = screen.visibleFrame.height
        return min(440, max(260, visibleHeight * 0.36))
    }

    private var chromeInteractionAccent: Color {
        theme.accent
    }

    /// Flip the haptic preference and fire one pulse on the way *on* so the user feels
    /// what they just enabled. Off doesn't pulse - silence is its whole point.
    private func toggleHapticFeedback() {
        var prefs = appState.appearancePreferences
        prefs.hapticFeedbackEnabled.toggle()
        appState.replaceAppearancePreferences(prefs)
        NookHaptics.confirm(enabled: prefs.hapticFeedbackEnabled)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                section("Appearance") {
                    NookAppearanceSettingsSection(appState: appState)
                }

                section("Display") {
                    DisplaySettingsSection(appState: appState)
                }

                section("Shortcut & nook") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsShortcutRow(appState: appState)
                        if !appState.hotkeyRegistrationFailures.keys.filter({ $0 != NookHotkeyIDs.toggle }).isEmpty {
                            SettingsHotkeyFailureRow(appState: appState)
                        }
                        SettingActionLine(
                            icon: appState.keepNookOpen ? "pin.fill" : "pin",
                            title: "Stay expanded",
                            detail: appState.keepNookOpen ? "On — nook stays open after hover ends" : "Off — closes when the pointer leaves",
                            accent: chromeInteractionAccent,
                            action: onToggleKeepOpen
                        )
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

                section("Data") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsDataCommandRow(
                            title: "Preview status banner",
                            subtitle: "Shows the transient message channel under the top bar",
                            icon: "text.bubble",
                            style: .standard,
                            action: {
                                appState.errorMessage = "Something went wrong — try again."
                                appState.showHome()
                            }
                        )
                        SettingsDataCommandRow(
                            title: "Reset All Settings",
                            subtitle: "Theme, surface, layout, display, hotkey, stay expanded",
                            icon: "arrow.counterclockwise",
                            style: .standard,
                            action: onResetAllSettings
                        )
                    }
                }

                section("About") {
                    SettingsAboutCard()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: settingsScrollMaxHeight, alignment: .leading)
    }

    /// A collapsible section bound to ``expandedSections``: a disclosure header, and - when
    /// open - the content indented under a connector hairline.
    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        SettingsDisclosureSection(
            title: title,
            isExpanded: Binding(
                get: { expandedSections.contains(title) },
                set: { open in
                    if open { expandedSections.insert(title) } else { expandedSections.remove(title) }
                }
            ),
            content: content
        )
    }
}

/// A settings section with a tap-to-toggle disclosure header and a left connector hairline
/// tying the indented content back to the header.
private struct SettingsDisclosureSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.nookResolvedTheme) private var theme

    /// Width of the leading icon gutter the top bar's home/lock/gear icons occupy (24×24).
    /// The disclosure chevron centers in the same gutter so the arrows sit directly under
    /// the top-left home icon, and the connector hairline runs down its middle.
    private let iconGutter: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.quaternaryLabel)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: iconGutter)
                    SettingsSectionLabel(title)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(alignment: .top, spacing: 12) {
                    // Connector: a thin vertical rule that fills the content height, tying the
                    // indented items back to the header. Centered under the chevron gutter.
                    RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                        .fill(theme.subtleStroke.opacity(0.5))
                        .frame(width: 1)

                    content()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, (iconGutter - 1) / 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
