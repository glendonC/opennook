// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Settings row for the global show/hide hotkey. Tap the shortcut to record a new one:
/// the next modifier + key combination is captured, persisted via `AppState`, and
/// re-registered live by `AppCoordinator`. Escape cancels.
struct SettingsShortcutRow: View {
    @ObservedObject var appState: AppState

    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookHostBranding) private var branding
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.headerInactiveIcon)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("Show \(branding.hostName)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.primaryLabel.opacity(0.95))
                if let failure = appState.hotkeyRegistrationFailures[NookHotkeyIDs.toggle] {
                    Text(failure.message)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color.orange)
                } else {
                    Text(isRecording ? "Press a shortcut — Esc to cancel" : "Global shortcut — click to change")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(theme.tertiaryLabel)
                }
            }

            Spacer(minLength: 8)

            Button(action: toggleRecording) {
                if isRecording {
                    Text("Listening…")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.primaryLabel.opacity(0.9))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 22)
                        .background(theme.subtleFill.opacity(0.7), in: Capsule())
                        .overlay(Capsule().stroke(theme.accent.opacity(0.6), lineWidth: 1))
                } else {
                    HStack(spacing: 4) {
                        ForEach(Array(appState.hotkey.displaySymbols.enumerated()), id: \.offset) { _, symbol in
                            ShortcutKeySquircle(symbol: symbol)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Show \(branding.hostName) shortcut, currently \(appState.hotkey.displaySymbols.joined(separator: " "))")
        .accessibilityHint("Activates to record a new shortcut")
        .onDisappear { stopRecording() }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        appState.isRecordingHotkey = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels without changing the shortcut.
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            if let hotkey = NookHotkey(event: event) {
                appState.replaceHotkey(hotkey)
                stopRecording()
            }
            // Swallow the event either way so it doesn't reach the rest of the app
            // while recording - including a partial combo that isn't valid yet.
            return nil
        }
    }

    private func stopRecording() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
        isRecording = false
        appState.isRecordingHotkey = false
    }
}

/// Surfaces hotkey-registration failures for the host-configured shortcuts - the
/// module direct-jump keys and the module-cycle key. The user-rebindable show/hide
/// shortcut reports its own failure inline in ``SettingsShortcutRow``; this row covers
/// the static shortcuts, which would otherwise fail silently. Renders nothing when
/// every static shortcut registered successfully.
struct SettingsHotkeyFailureRow: View {
    @ObservedObject var appState: AppState

    /// Failures for every shortcut except the show/hide toggle, sorted for stable order.
    private var staticFailures: [HotkeyRegistrationFailure] {
        appState.hotkeyRegistrationFailures
            .filter { $0.key != NookHotkeyIDs.toggle }
            .values
            .sorted { $0.shortcutName < $1.shortcutName }
    }

    var body: some View {
        if !staticFailures.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(staticFailures, id: \.shortcutName) { failure in
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.orange)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(failure.shortcutName)
                                .font(.system(size: 11, weight: .medium))
                            Text(failure.message)
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(Color.orange)
                        }
                        Spacer(minLength: 8)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(failure.shortcutName) shortcut unavailable: \(failure.message)")
                }
            }
            .padding(.vertical, 4)
        }
    }
}
