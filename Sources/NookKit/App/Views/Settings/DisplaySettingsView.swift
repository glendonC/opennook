// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import SwiftUI

/// Picks which display the Nook chrome appears on. Lives in its own Settings group.
///
/// Offers the two stable modes (built-in / main) plus one entry per attached display.
/// The display list refreshes on connect/disconnect; a previously-chosen display that's
/// since been unplugged stays selectable as a "(not connected)" row so the preference
/// isn't silently lost - the resolver falls back to the built-in display until it returns.
struct DisplaySettingsSection: View {
    @ObservedObject var appState: AppState
    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics

    @State private var displays: [NookScreenLocator.DisplayInfo] = NookScreenLocator.connectedDisplays()

    private static let builtInTag = "builtIn"
    private static let mainTag = "main"
    private static let specificTagPrefix = "uuid:"

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.settingsFieldSpacing) {
            Picker("Display", selection: selectionBinding) {
                Text("Built-in display").tag(Self.builtInTag)
                Text("Display with active menu bar").tag(Self.mainTag)
                if !specificOptions.isEmpty {
                    Divider()
                    ForEach(specificOptions, id: \.tag) { option in
                        Text(option.label).tag(option.tag)
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.small)
            .accessibilityLabel("Display")

            Text(descriptionText)
                .font(typography.settingsCaption)
                .foregroundStyle(theme.tertiaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in
            displays = NookScreenLocator.connectedDisplays()
        }
    }

    private var descriptionText: String {
        switch appState.displayPreference.mode {
            case .builtIn:
                return "The chrome stays on the built-in (notched) display."
            case .main:
                return "The chrome follows the display that currently hosts the menu bar."
            case .specific:
                let connected =
                    appState.displayPreference.displayUUID
                    .map { uuid in displays.contains { $0.uuid == uuid } } ?? false
                return connected
                    ? "The chrome is pinned to a specific display."
                    : "The chosen display isn't connected — using the built-in display until it returns."
        }
    }

    /// One option per attached display, plus a trailing "(not connected)" row when the
    /// saved `.specific` display isn't currently attached, so the picker can still show it.
    private var specificOptions: [(tag: String, label: String)] {
        var options = displays.map { display -> (tag: String, label: String) in
            (tag: Self.specificTagPrefix + display.uuid, label: display.name)
        }
        if appState.displayPreference.mode == .specific,
            let uuid = appState.displayPreference.displayUUID,
            !displays.contains(where: { $0.uuid == uuid })
        {
            options.append((tag: Self.specificTagPrefix + uuid, label: "Saved display (not connected)"))
        }
        return options
    }

    private var selectionBinding: Binding<String> {
        Binding(
            get: {
                let preference = appState.displayPreference
                switch preference.mode {
                    case .builtIn: return Self.builtInTag
                    case .main: return Self.mainTag
                    case .specific: return Self.specificTagPrefix + (preference.displayUUID ?? "")
                }
            },
            set: { tag in
                let next: NookDisplayPreference
                if tag == Self.builtInTag {
                    next = .builtIn
                } else if tag == Self.mainTag {
                    next = .main
                } else if tag.hasPrefix(Self.specificTagPrefix) {
                    next = .specific(String(tag.dropFirst(Self.specificTagPrefix.count)))
                } else {
                    next = .default
                }
                appState.replaceDisplayPreference(next)
            }
        )
    }
}
