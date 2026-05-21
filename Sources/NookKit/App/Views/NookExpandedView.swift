// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import SwiftUI

/// Top-level expanded notch surface. Renders the framework chrome — top bar plus the
/// Settings panel — and hosts the host app's registered `home` content in between.
///
/// The home surface is injected, not forked: `NookConfiguration` supplies the `home`
/// closure (defaulting to ``NookPlaceholderHomeView``). The top bar and Settings stay
/// framework-owned so every notch app gets them for free.
///
/// Sizing: the chrome sizes the panel to whatever this view measures. The demo pins a
/// stable `NookLayout.width` so the panel doesn't resize between the home and settings
/// surfaces — remove that `.frame(width:)` to let the panel size purely to content.
public struct NookExpandedView: View {
    @ObservedObject var appState: AppState

    let services: AppServices
    let toggleKeepOpen: () -> Void
    let hide: () -> Void
    let resetAllSettings: () -> Void

    /// Resolves the chrome palette for each layout pass. Host apps override this through
    /// ``NookConfiguration/theme``; the default is ``NookResolvedTheme/live(appState:)``.
    let theme: (AppState) -> NookResolvedTheme

    /// Host-registered home content, shown between the top bar and (when toggled) Settings.
    let home: () -> AnyView

    /// Host-configurable top-bar leading label and icon (see `NookConfiguration`).
    let topBarLeadingTitle: (AppState) -> String
    let topBarLeadingIcon: String?

    /// Whether the framework top bar and Settings screen are part of the chrome
    /// (see ``NookConfiguration/showsTopBar`` / ``NookConfiguration/showsSettings``).
    let showsTopBar: Bool
    let showsSettings: Bool

    @State private var isHomeIconHovered = false

    public init(
        appState: AppState,
        services: AppServices,
        toggleKeepOpen: @escaping () -> Void,
        hide: @escaping () -> Void,
        resetAllSettings: @escaping () -> Void,
        theme: @escaping (AppState) -> NookResolvedTheme = NookResolvedTheme.live,
        home: @escaping () -> AnyView = { AnyView(NookPlaceholderHomeView()) },
        topBarLeadingTitle: @escaping (AppState) -> String = { _ in "Home" },
        topBarLeadingIcon: String? = "house",
        showsTopBar: Bool = true,
        showsSettings: Bool = true
    ) {
        self.appState = appState
        self.services = services
        self.toggleKeepOpen = toggleKeepOpen
        self.hide = hide
        self.resetAllSettings = resetAllSettings
        self.theme = theme
        self.home = home
        self.topBarLeadingTitle = topBarLeadingTitle
        self.topBarLeadingIcon = topBarLeadingIcon
        self.showsTopBar = showsTopBar
        self.showsSettings = showsSettings
    }

    private var resolvedTheme: NookResolvedTheme {
        theme(appState)
    }

    private var chromeInteractionAccent: Color {
        Color(nsColor: .controlAccentColor)
    }

    public var body: some View {
        VStack(spacing: 8) {
            if showsTopBar {
                NookTopBar(
                    appState: appState,
                    chromeInteractionAccent: chromeInteractionAccent,
                    isHomeIconHovered: $isHomeIconHovered,
                    toggleKeepOpen: toggleKeepOpen,
                    leadingTitle: topBarLeadingTitle,
                    leadingIcon: topBarLeadingIcon,
                    showsSettings: showsSettings
                )
            }

            Group {
                if showsSettings && appState.isSettingsView {
                    settingsSurface
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            )
                        )
                } else {
                    homeSurface
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .leading)),
                                removal: .opacity.combined(with: .move(edge: .trailing))
                            )
                        )
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.84), value: appState.viewMode)
        }
        .frame(width: NookLayout.width)
        .padding(NookLayout.edgePadding)
        .environment(\.nookResolvedTheme, resolvedTheme)
        .environment(\.appServices, services)
        // The nook lives on a `.nonactivatingPanel` so opening it never steals focus from
        // the user's editor. Side effect: until the user clicks the surface, AppKit
        // desaturates accent-tinted controls. Forcing `.active` makes the chrome paint as
        // if focused without changing key-window behaviour.
        .environment(\.controlActiveState, .active)
        .tint(.accentColor)
        .preferredColorScheme(appState.appearancePreferences.chromeColorSchemeOverride)
        .onChange(of: appState.viewMode) { _ in
            isHomeIconHovered = false
        }
        .onExitCommand(perform: hide)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: appState.viewMode)
    }

    /// Host-registered home surface. Supplied via ``NookConfiguration`` — no fork needed.
    private var homeSurface: some View {
        home()
    }

    private var settingsSurface: some View {
        SettingsView(
            appState: appState,
            onToggleKeepOpen: toggleKeepOpen,
            onResetAllSettings: resetAllSettings
        )
    }
}
