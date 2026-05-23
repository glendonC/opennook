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

    let toggleKeepOpen: () -> Void
    let hide: () -> Void
    let resetAllSettings: () -> Void
    let switchModule: (String) -> Void

    var body: some View {
        let configuration = moduleHost.configuration
        VStack(spacing: 0) {
            // The switcher is persistent chrome: it sits outside the `.id`-keyed content
            // below, so it does not cross-fade when the module changes under it.
            if moduleHost.isMultiModule {
                ModuleSwitcherBar(moduleHost: moduleHost, switchModule: switchModule)
            }

            NookExpandedView(
                appState: appState,
                services: moduleHost.activeServices,
                toggleKeepOpen: toggleKeepOpen,
                hide: hide,
                resetAllSettings: resetAllSettings,
                theme: configuration.theme,
                home: configuration.home,
                topBar: configuration.topBar
            )
            // Identity tracks the active module so a switch tears down the old content
            // and inserts the new — letting the transition cross-fade rather than diff
            // in place.
            .id(moduleHost.activeModuleID)
            .transition(.opacity)
        }
        // The switcher reads `\.nookResolvedTheme`; NookExpandedView re-sets it for its
        // own subtree, so this only reaches the switcher bar.
        .environment(\.nookResolvedTheme, configuration.theme(appState))
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
