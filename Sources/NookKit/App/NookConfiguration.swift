// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// The host-app registration seam — everything a notch app customizes without forking
/// the framework.
///
/// Pass one to `NookApp.main(_:)`. The default value reproduces the demo exactly, so
/// `NookApp.main()` is unchanged. The common case is a single registered view:
///
/// ```swift
/// NookApp.main { MyHomeView() }
/// ```
///
/// The fuller form reaches every knob:
///
/// ```swift
/// var configuration = NookConfiguration()
/// configuration.setHome { MyHomeView() }
/// configuration.setCompactTrailing { MyGlyph() }
/// configuration.theme = { appState in MyPalette.resolve(appState) }
/// configuration.onExpand = { print("nook expanded") }
/// NookApp.main(configuration)
/// ```
///
/// > Note: This is a *registration* entry point, distinct from the `NookSurface`-level
/// > customization types (`NookStyle`, `NookHoverBehavior`, …). It exists so a host can
/// > depend on the package and customize through public API only.
public struct NookConfiguration {
    /// The expanded home surface, shown between the framework top bar and Settings.
    /// Use ``setHome(_:)`` to set it from a `@ViewBuilder`.
    public var home: () -> AnyView

    /// Content for the compact slot to the **left** of the notch. Use
    /// ``setCompactLeading(_:)`` to set it from a `@ViewBuilder`.
    public var compactLeading: () -> AnyView

    /// Content for the compact slot to the **right** of the notch. Use
    /// ``setCompactTrailing(_:)`` to set it from a `@ViewBuilder`.
    public var compactTrailing: () -> AnyView

    /// Resolves the chrome palette. Defaults to ``NookResolvedTheme/live(appState:)``;
    /// supply a closure returning a host-built ``NookResolvedTheme`` to theme the chrome.
    public var theme: (AppState) -> NookResolvedTheme

    /// The label for the top bar's leading cluster. Defaults to `"Home"` — override it
    /// so the bar communicates *product* context (a date, a section name) rather than
    /// the demo's navigation metaphor. The closure receives ``AppState`` for hosts whose
    /// label depends on it.
    ///
    /// The framework top bar, lock/gear controls, and the Settings breadcrumb are
    /// unaffected — only the leading icon + title are host-configurable.
    public var topBarLeadingTitle: (AppState) -> String

    /// SF Symbol for the top bar's leading cluster. Defaults to `"house"`. Set to `nil`
    /// for a title-only cluster (in Settings, a back chevron is then used so returning
    /// home still works).
    public var topBarLeadingIcon: String?

    /// Whether the expanded surface renders the framework top bar (leading cluster,
    /// keep-open lock, gear). Defaults to `true`. Set to `false` for a bare expanded
    /// surface — a pure glance/widget with no framework chrome.
    ///
    /// With the top bar off the gear is gone, so Settings is unreachable from the
    /// chrome regardless of ``showsSettings``; the keep-open lock is gone too (it lives
    /// only in the top bar). Both remain reachable via the menu-bar fallback.
    public var showsTopBar: Bool = true

    /// Whether the gear and the reachable Settings screen are part of the chrome.
    /// Defaults to `true`. Set to `false` to drop the Settings UI entirely — the gear
    /// is removed, the menu-bar "Settings…" item is dropped, and the expanded surface
    /// stays on the home view.
    public var showsSettings: Bool = true

    /// Called when the chrome transitions into the expanded surface (from any source).
    public var onExpand: (() -> Void)?

    /// Called when the chrome transitions into the compact pill.
    public var onCompact: (() -> Void)?

    /// Called when the chrome transitions into the hidden state.
    public var onHide: (() -> Void)?

    /// Handles a file drop on the notch panel. Return `true` to accept the URLs
    /// (the nook stays expanded so any registration UI is visible), `false` to
    /// reject. `nil` — the default — rejects all drops.
    ///
    /// `NookComponents`' file shelf wires its `ShelfStore.accept` straight into
    /// this; a host can also route drops through its own import flow.
    public var onFileDrop: (([URL]) -> Bool)?

    /// Called once, on the main actor, at the end of `AppCoordinator.start()` — a
    /// post-launch handle on the live coordinator.
    ///
    /// `NookComponents`' activity queue uses this to `bind` itself to the coordinator
    /// (which conforms to ``NookSurfacePresenting``); a host can also use it to drive
    /// the chrome or observe state after launch.
    ///
    /// Typed `@MainActor` — it always runs on the main actor — so the callback may call
    /// main-actor-isolated API (e.g. `NookActivityQueue.bind`) directly.
    public var onReady: (@MainActor (AppCoordinator) -> Void)?

    /// Creates a configuration matching the framework demo: the placeholder home view,
    /// the default compact glyphs, the live system theme, and no lifecycle callbacks.
    public init() {
        home = { AnyView(NookPlaceholderHomeView()) }
        compactLeading = { AnyView(NookCompactLeadingView()) }
        compactTrailing = { AnyView(NookCompactTrailingView()) }
        theme = NookResolvedTheme.live
        topBarLeadingTitle = { _ in "Home" }
        topBarLeadingIcon = "house"
        showsTopBar = true
        showsSettings = true
    }

    /// Registers the expanded home surface from a `@ViewBuilder` closure.
    public mutating func setHome<Content: View>(@ViewBuilder _ content: @escaping () -> Content) {
        home = { AnyView(content()) }
    }

    /// Registers the left compact-slot content from a `@ViewBuilder` closure.
    public mutating func setCompactLeading<Content: View>(@ViewBuilder _ content: @escaping () -> Content) {
        compactLeading = { AnyView(content()) }
    }

    /// Registers the right compact-slot content from a `@ViewBuilder` closure.
    public mutating func setCompactTrailing<Content: View>(@ViewBuilder _ content: @escaping () -> Content) {
        compactTrailing = { AnyView(content()) }
    }
}
