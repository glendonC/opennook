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
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.headerInactiveIcon)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("Show Nook")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.primaryLabel.opacity(0.95))
                if let error = appState.errorMessage {
                    Text(error)
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
                        .overlay(Capsule().stroke(Color.accentColor.opacity(0.6), lineWidth: 1))
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
        .accessibilityLabel("Show Nook shortcut, currently \(appState.hotkey.displaySymbols.joined(separator: " "))")
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
            // while recording — including a partial combo that isn't valid yet.
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
