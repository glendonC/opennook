// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import NookSurface
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
    /// `@Sendable @MainActor` to match ``NookConfiguration/theme``.
    let theme: @Sendable @MainActor (AppState) -> NookResolvedTheme

    /// Host-registered home content, shown between the top bar and (when toggled) Settings.
    let home: @Sendable @MainActor () -> AnyView

    /// Host-registered Settings content. `nil` uses the framework's built-in Settings UI.
    /// See ``NookConfiguration/settings``.
    let settings: (@Sendable @MainActor () -> AnyView)?

    /// The framework top bar's host-configurable surface — leading cluster, top-bar
    /// visibility, Settings visibility. See ``NookTopBarConfiguration``.
    let topBar: NookTopBarConfiguration

    /// Fixed width for the expanded surface. Host apps set this through
    /// ``NookConfiguration/expandedWidth``; the default is ``NookLayout/width``.
    let width: CGFloat

    @State private var isHomeIconHovered = false

    /// Insets injected by the chrome (`NookSurface`) relative to this view's
    /// outer frame. The VStack below sits inside ``NookLayout/edgePadding``, so
    /// re-inject a reduced copy of the insets for the top-bar and the host's
    /// home/settings surface to read — they see clearance relative to their
    /// own frame, not the outer one.
    @Environment(\.nookContentInsets) private var outerContentInsets

    public init(
        appState: AppState,
        services: AppServices,
        toggleKeepOpen: @escaping () -> Void,
        hide: @escaping () -> Void,
        resetAllSettings: @escaping () -> Void,
        theme: @escaping @Sendable @MainActor (AppState) -> NookResolvedTheme
            = { NookResolvedTheme.live(appState: $0) },
        home: @escaping @Sendable @MainActor () -> AnyView = { AnyView(NookPlaceholderHomeView()) },
        settings: (@Sendable @MainActor () -> AnyView)? = nil,
        topBar: NookTopBarConfiguration = .default,
        width: CGFloat = NookLayout.width
    ) {
        self.appState = appState
        self.services = services
        self.toggleKeepOpen = toggleKeepOpen
        self.hide = hide
        self.resetAllSettings = resetAllSettings
        self.theme = theme
        self.home = home
        self.settings = settings
        self.topBar = topBar
        self.width = width
    }

    private var resolvedTheme: NookResolvedTheme {
        theme(appState)
    }

    private var chromeInteractionAccent: Color {
        resolvedTheme.accent
    }

    public var body: some View {
        VStack(spacing: 8) {
            if topBar.showsTopBar {
                NookTopBar(
                    appState: appState,
                    chromeInteractionAccent: chromeInteractionAccent,
                    isHomeIconHovered: $isHomeIconHovered,
                    toggleKeepOpen: toggleKeepOpen,
                    leadingTitle: topBar.leadingTitle,
                    leadingIcon: topBar.leadingIcon,
                    showsSettings: topBar.showsSettings
                )
            }

            Group {
                if topBar.showsSettings && appState.isSettingsView {
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
        .environment(\.nookContentInsets, outerContentInsets.reducingBy(NookLayout.edgePadding))
        .frame(width: width)
        .padding(NookLayout.edgePadding)
        .environment(\.nookResolvedTheme, resolvedTheme)
        .environment(\.appServices, services)
        // Expose `AppState` to the host-registered `home` surface so it can observe
        // chrome-level state (e.g. `isDragInFlight`) without each closure needing a
        // bespoke parameter.
        .environmentObject(appState)
        // The nook lives on a `.nonactivatingPanel` so opening it never steals focus from
        // the user's editor. Side effect: until the user clicks the surface, AppKit
        // desaturates accent-tinted controls. Forcing `.active` makes the chrome paint as
        // if focused without changing key-window behaviour.
        .environment(\.controlActiveState, .active)
        .tint(resolvedTheme.accent)
        .fontDesign(resolvedTheme.fontDesign)
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

    @ViewBuilder
    private var settingsSurface: some View {
        if let settings {
            settings()
        } else {
            SettingsView(
                appState: appState,
                onToggleKeepOpen: toggleKeepOpen,
                onResetAllSettings: resetAllSettings
            )
        }
    }
}
