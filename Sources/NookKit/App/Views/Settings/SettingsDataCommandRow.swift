// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Visual treatment buckets for `SettingsDataCommandRow`. Standard for benign actions,
/// destructive for "this can't be undone."
enum SettingsDataCommandStyle {
    case standard
    case destructive
}

/// Tap row used inside the Data settings group: icon plate, title + subtitle, trailing chevron.
struct SettingsDataCommandRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let style: SettingsDataCommandStyle
    let action: () -> Void

    @Environment(\.nookResolvedTheme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(titleTint)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(theme.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isHovering ? iconTint : theme.quaternaryLabel)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var iconTint: Color {
        switch style {
        case .standard:
            isHovering ? theme.accent : theme.headerInactiveIcon
        case .destructive:
            Color.red.opacity(0.92)
        }
    }

    private var titleTint: Color {
        switch style {
        case .standard:
            isHovering ? theme.accent : theme.primaryLabel
        case .destructive:
            Color.red.opacity(0.95)
        }
    }
}

/// About card surfaced in the About settings group: host name, version, and a one-line
/// note about the host. Name and tagline come from `\.nookHostBranding` so downstream
/// hosts read their own product name — the demo's `"Nook"` / stock tagline are the
/// defaults.
struct SettingsAboutCard: View {
    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookHostBranding) private var branding

    /// Reads `CFBundleShortVersionString` from the running bundle. The SPM `swift run`
    /// build has no `Info.plist` on disk, so it falls back to the package version.
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    /// Default tagline used when the host has not overridden ``NookHostBranding/hostTagline``.
    /// References OpenNook as the framework, not the host product — the host's
    /// own marketing copy belongs in a `hostTagline` override.
    private static let defaultTagline =
        "A demo notch app built with OpenNook, an open-source framework for macOS notch apps."

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.headerInactiveIcon)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(branding.hostName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.primaryLabel.opacity(0.95))
                    Text("v\(version)")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(theme.tertiaryLabel)
                }
                Text(branding.hostTagline ?? Self.defaultTagline)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
