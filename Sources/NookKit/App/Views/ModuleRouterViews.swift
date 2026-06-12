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
        NookExpandedView(
            appState: appState,
            services: moduleHost.activeServices,
            toggleKeepOpen: toggleKeepOpen,
            hide: hide,
            resetAllSettings: resetAllSettings,
            theme: configuration.theme,
            home: configuration.home,
            settings: configuration.settings,
            topBar: configuration.topBar,
            labels: configuration.labels,
            metrics: configuration.metrics,
            motion: configuration.motion,
            width: configuration.expandedWidth ?? NookLayout.width,
            // Only fold a switcher into the chrome when the host opted in; otherwise the
            // surface is untouched and switching lives in the menu bar / hotkeys.
            moduleSwitcher: leadingClusterSwitcher
        )
        // Identity tracks the active module so a switch tears down the old content and
        // inserts the new — letting the transition cross-fade rather than diff in place.
        .id(moduleHost.activeModuleID)
        .transition(.opacity)
        // Host-product identity (brand mark, About card, show-hide hotkey label) lives on
        // `ModuleHost`; surface it so the chrome can read it without an init-time plumb.
        .environment(\.nookHostBranding, moduleHost.branding)
    }

    /// The in-surface switcher payload, built only when the host opted into
    /// ``NookModuleSwitcherPlacement/leadingCluster`` and more than one module is
    /// registered. `nil` leaves the top bar's leading cluster the plain module title.
    private var leadingClusterSwitcher: NookModuleSwitcher? {
        guard moduleHost.isMultiModule, moduleHost.switcherPlacement.foldsIntoLeadingCluster else {
            return nil
        }
        return NookModuleSwitcher(
            modules: moduleHost.descriptors,
            activeID: moduleHost.activeModuleID,
            attentionIDs: moduleHost.attentionModuleIDs,
            switchTo: switchModule
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
        // The compact slots render in their own view tree (not under NookExpandedView),
        // so inject the metrics here too — the default compact glyphs read
        // `compactSlotSize` from it.
        .environment(\.nookChromeMetrics, configuration.metrics)
    }
}
