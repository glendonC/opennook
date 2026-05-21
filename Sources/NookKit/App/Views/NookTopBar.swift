// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Topbar for the expanded notch.
///
/// Minimal by design: a tiny home cluster on the left (matched to right-side icon
/// weight), and the keep-open / gear glyphs on the right. The only chrome-level
/// toggle is between the home surface and settings — everything else belongs to
/// whatever home view a downstream fork plugs in.
struct NookTopBar: View {
    @ObservedObject var appState: AppState
    let chromeInteractionAccent: Color
    @Binding var isHomeIconHovered: Bool
    let toggleKeepOpen: () -> Void

    /// Host-configurable leading-cluster label and icon (see `NookConfiguration`).
    let leadingTitle: (AppState) -> String
    let leadingIcon: String?

    @Environment(\.nookResolvedTheme) private var resolvedTheme

    var body: some View {
        HStack(spacing: 8) {
            homeLeadingCluster
                .fixedSize(horizontal: true, vertical: false)

            if appState.isSettingsView {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(resolvedTheme.quaternaryLabel)

                Text("Settings")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(resolvedTheme.secondaryLabel)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                HeaderIcon(
                    systemName: appState.keepNookOpen ? "lock.fill" : "lock.open",
                    isActive: appState.keepNookOpen,
                    activeColor: chromeInteractionAccent,
                    help: "Stay expanded after hover"
                ) {
                    toggleKeepOpen()
                }

                HeaderIcon(
                    systemName: "gearshape",
                    isActive: appState.isSettingsView,
                    activeColor: chromeInteractionAccent,
                    help: "Settings"
                ) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                        if appState.isSettingsView {
                            appState.showHome()
                        } else {
                            appState.showSettings()
                        }
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: 24)
    }

    /// On home the configured title stays visible next to its icon; in settings (and any
    /// other future deep view) the label collapses until the user hovers the glyph, which
    /// doubles as the back-to-home control. Label and icon come from `NookConfiguration`;
    /// the defaults reproduce the demo's house + "Home".
    private var homeLeadingCluster: some View {
        let showPersistentHomeTitle = appState.isHomeView && !appState.isSettingsView
        let title = leadingTitle(appState)

        return HStack(spacing: 6) {
            if showPersistentHomeTitle {
                if let leadingIcon {
                    StaticHeaderIcon(systemName: leadingIcon)
                }
                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(resolvedTheme.secondaryLabel)
                    .lineLimit(1)
            } else {
                // Settings (or any deep view): the cluster is the back-to-home control.
                // With no configured icon, a back chevron keeps that affordance.
                HeaderIcon(
                    systemName: leadingIcon ?? "chevron.left",
                    isActive: false,
                    activeColor: chromeInteractionAccent,
                    help: title
                ) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                        appState.showHome()
                    }
                }
                .accessibilityLabel(title)
                .onHover { isHomeIconHovered = $0 }

                if isHomeIconHovered {
                    Text(title)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(resolvedTheme.secondaryLabel)
                        .lineLimit(1)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .offset(x: -6)),
                                removal: .opacity.combined(with: .offset(x: -4))
                            )
                        )
                }
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isHomeIconHovered)
    }
}
