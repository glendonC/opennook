// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Expanded-surface router. `Nook` builds its expanded content closure exactly once,
/// so to swap modules at runtime the *view* — not the closure — must observe the
/// ``ModuleHost``. When ``ModuleHost/configuration`` is re-published, this view's body
/// re-evaluates and rebuilds ``NookExpandedView`` from the new configuration: new home
/// content, new theme, new chrome opt-outs.
struct ModuleRouterExpandedView: View {
    @ObservedObject var moduleHost: ModuleHost
    @ObservedObject var appState: AppState

    let services: AppServices
    let toggleKeepOpen: () -> Void
    let hide: () -> Void
    let resetAllSettings: () -> Void

    var body: some View {
        let configuration = moduleHost.configuration
        NookExpandedView(
            appState: appState,
            services: services,
            toggleKeepOpen: toggleKeepOpen,
            hide: hide,
            resetAllSettings: resetAllSettings,
            theme: configuration.theme,
            home: configuration.home,
            topBarLeadingTitle: configuration.topBarLeadingTitle,
            topBarLeadingIcon: configuration.topBarLeadingIcon,
            showsTopBar: configuration.showsTopBar,
            showsSettings: configuration.showsSettings
        )
    }
}

/// Compact-slot router — the collapsed-pill counterpart to ``ModuleRouterExpandedView``.
/// One instance per slot; both observe the same ``ModuleHost`` so a module switch
/// re-renders the leading and trailing glyphs together.
struct ModuleRouterCompactView: View {
    enum Slot {
        case leading
        case trailing
    }

    @ObservedObject var moduleHost: ModuleHost
    @ObservedObject var appState: AppState
    let slot: Slot

    var body: some View {
        let configuration = moduleHost.configuration
        let content = slot == .leading ? configuration.compactLeading : configuration.compactTrailing
        NookCompactHost(
            appState: appState,
            theme: configuration.theme,
            content: content
        )
    }
}
