// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookSurface
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
public struct NookConfiguration: Sendable {
    /// The expanded home surface, shown between the framework top bar and Settings.
    /// Use ``setHome(_:)`` to set it from a `@ViewBuilder`.
    ///
    /// `@MainActor`: these content/theme closures build SwiftUI views and resolve the
    /// chrome palette, which only ever happens during main-actor view rendering.
    /// `@Sendable`: a `NookConfiguration` is assembled at launch and handed to the
    /// main-actor coordinator, so the whole value is `Sendable` — every closure it
    /// carries crosses that boundary and must be too.
    public var home: @Sendable @MainActor () -> AnyView

    /// Content for the compact slot to the **left** of the notch. Use
    /// ``setCompactLeading(_:)`` to set it from a `@ViewBuilder`.
    public var compactLeading: @Sendable @MainActor () -> AnyView

    /// Content for the compact slot to the **right** of the notch. Use
    /// ``setCompactTrailing(_:)`` to set it from a `@ViewBuilder`.
    public var compactTrailing: @Sendable @MainActor () -> AnyView

    /// Resolves the chrome palette. Defaults to ``NookResolvedTheme/live(appState:)``;
    /// supply a closure returning a host-built ``NookResolvedTheme`` to theme the chrome.
    public var theme: @Sendable @MainActor (AppState) -> NookResolvedTheme

    /// Replaces the built-in Settings surface (reached via the gear) with host content.
    /// `nil` (the default) uses the framework Settings UI. Use ``setSettings(_:)`` to set
    /// it from a `@ViewBuilder`. Gated by ``NookTopBarConfiguration/showsSettings`` like
    /// the built-in screen; the host view reads ``AppState`` via `@EnvironmentObject`.
    public var settings: (@Sendable @MainActor () -> AnyView)? = nil

    /// Top-bar configuration — leading cluster (title/icon), and the two visibility
    /// flags for the top bar and the Settings UI. Grouped so the related knobs
    /// travel together and future top-bar settings land here cleanly. See
    /// ``NookTopBarConfiguration``.
    public var topBar: NookTopBarConfiguration

    /// Launch *seed* values for the process-global preferences (appearance, global
    /// hotkey, display target). On the single-module path (`NookApp.main(_:)` with a
    /// `NookConfiguration`) this is forwarded onto the synthesized
    /// ``NookHostConfiguration/preferenceDefaults``; multi-module hosts set it on
    /// ``NookHostConfiguration`` directly. Defaults to ``NookPreferenceDefaults/default``
    /// (today's framework behavior). See ``NookPreferenceDefaults`` for the
    /// seed-vs-persisted semantics.
    public var preferenceDefaults: NookPreferenceDefaults = .default

    /// Process-global chrome behavior — hover side-effects, the cold-launch shimmer, and
    /// the appearance→backdrop mapping. On the single-module path this is forwarded onto
    /// the synthesized ``NookHostConfiguration/chromeBehavior``; multi-module hosts set it
    /// on ``NookHostConfiguration`` directly. Defaults to ``NookChromeBehavior/default``
    /// (today's framework behavior). See ``NookChromeBehavior``.
    public var chromeBehavior: NookChromeBehavior = .default

    /// Overrides the chrome's corner radii — the small rounding into the notch arch and
    /// the larger rounding where the panel meets the wallpaper. `nil` (the default) uses
    /// the framework's radii, tuned to sit well under the menu bar on notched MacBooks.
    /// See ``NookStyle``.
    public var style: NookStyle? = nil

    /// Overrides the expand / collapse / compact↔expanded animation curves. `nil` (the
    /// default) uses the framework's soft springs. Supply a ``NookTransitionConfiguration``
    /// to retune or to slow the chrome down (set its `animationDuration` so awaited
    /// `expand()`/`compact()` still return once the chrome has visibly arrived).
    public var transitions: NookTransitionConfiguration? = nil

    /// Fixed width, in points, for the expanded surface. `nil` (the default) uses the
    /// framework width (520pt). The chrome is content-driven and sizes to fit; this only
    /// pins a stable width so the panel doesn't resize when switching between the home
    /// and Settings surfaces.
    public var expandedWidth: CGFloat? = nil

    /// Called when the chrome transitions into the expanded surface (from any source).
    ///
    /// `@Sendable @MainActor`: the lifecycle hooks fire on the surface's main-actor
    /// state transitions, and a `NookConfiguration` is itself `Sendable`.
    public var onExpand: (@Sendable @MainActor () -> Void)?

    /// Called when the chrome transitions into the compact pill.
    public var onCompact: (@Sendable @MainActor () -> Void)?

    /// Called when the chrome transitions into the hidden state.
    public var onHide: (@Sendable @MainActor () -> Void)?

    /// Handles a file drop on the notch panel. Return `true` to accept the URLs
    /// (the nook stays expanded so any registration UI is visible), `false` to
    /// reject. `nil` — the default — rejects all drops.
    ///
    /// `NookComponents`' file shelf wires its `ShelfStore.accept` straight into
    /// this; a host can also route drops through its own import flow.
    public var onFileDrop: (@Sendable @MainActor ([URL]) -> Bool)?

    /// Called once, on the main actor, at the end of `AppCoordinator.start()` — a
    /// post-launch handle on the live coordinator.
    ///
    /// `NookComponents`' activity queue uses this to `bind` itself to the coordinator
    /// (which conforms to ``NookSurfacePresenting``); a host can also use it to drive
    /// the chrome or observe state after launch.
    ///
    /// Typed `@MainActor` — it always runs on the main actor — so the callback may call
    /// main-actor-isolated API (e.g. `NookActivityQueue.bind`) directly.
    public var onReady: (@Sendable @MainActor (AppCoordinator) -> Void)?

    /// Creates a configuration matching the framework demo: the placeholder home view,
    /// the default compact glyphs, the live system theme, and no lifecycle callbacks.
    public init() {
        home = { AnyView(NookPlaceholderHomeView()) }
        compactLeading = { AnyView(NookCompactLeadingView()) }
        compactTrailing = { AnyView(NookCompactTrailingView()) }
        // Wrapped in a closure literal rather than passed as a bare function reference:
        // the `theme` slot is `@Sendable`, and a closure that captures nothing and just
        // forwards to the `@MainActor` `live(appState:)` satisfies that cleanly.
        theme = { NookResolvedTheme.live(appState: $0) }
        topBar = .default
    }

    /// Registers the expanded home surface from a `@ViewBuilder` closure.
    ///
    /// The closure is `@MainActor` because it builds a SwiftUI view, and `@Sendable` so
    /// these (nonisolated) `mutating` setters can store it into the main-actor `home`
    /// slot — which a `Sendable` `NookConfiguration` requires — without a "sending"
    /// violation. `Content: Sendable` lets the stored `@Sendable` wrapper close over the
    /// `Content` metatype; a SwiftUI view value is a `Sendable` value type in practice.
    public mutating func setHome<Content: View & Sendable>(
        @ViewBuilder _ content: @escaping @Sendable @MainActor () -> Content
    ) {
        home = { AnyView(content()) }
    }

    /// Registers the left compact-slot content from a `@ViewBuilder` closure.
    public mutating func setCompactLeading<Content: View & Sendable>(
        @ViewBuilder _ content: @escaping @Sendable @MainActor () -> Content
    ) {
        compactLeading = { AnyView(content()) }
    }

    /// Registers the right compact-slot content from a `@ViewBuilder` closure.
    public mutating func setCompactTrailing<Content: View & Sendable>(
        @ViewBuilder _ content: @escaping @Sendable @MainActor () -> Content
    ) {
        compactTrailing = { AnyView(content()) }
    }

    /// Registers a custom Settings surface from a `@ViewBuilder` closure, replacing the
    /// framework's built-in Settings screen. Reachable via the gear (keep
    /// ``NookTopBarConfiguration/showsSettings`` on); the content can read ``AppState``
    /// through `@EnvironmentObject`.
    public mutating func setSettings<Content: View & Sendable>(
        @ViewBuilder _ content: @escaping @Sendable @MainActor () -> Content
    ) {
        settings = { AnyView(content()) }
    }

    /// Registers host actions for the top bar's trailing cluster from a `@ViewBuilder`
    /// closure. The items render immediately left of the framework's keep-open lock and
    /// gear, themed and able to observe ``AppState``. See
    /// ``NookTopBarConfiguration/trailingItems`` for the space/clipping guidance — keep
    /// these compact glyph-style buttons.
    public mutating func setTopBarTrailingItems<Content: View & Sendable>(
        @ViewBuilder _ content: @escaping @Sendable @MainActor () -> Content
    ) {
        topBar.trailingItems = { AnyView(content()) }
    }
}

/// The framework top bar's host-configurable surface — the leading cluster
/// (title / icon), plus the two flags that strip the bar or the Settings UI for
/// hosts that want a bare glance/widget chrome.
///
/// These knobs travel together because every one of them is "should the top bar
/// look like X." Grouping them keeps ``NookConfiguration`` from accreting four loose
/// fields, and gives future top-bar settings a natural home.
public struct NookTopBarConfiguration: Sendable {
    /// Whether the expanded surface renders the framework top bar (leading cluster,
    /// keep-open lock, gear). Defaults to `true`. Set to `false` for a bare expanded
    /// surface — a pure glance/widget with no framework chrome.
    ///
    /// With the top bar off the gear is gone, so Settings is unreachable from the
    /// chrome regardless of ``showsSettings``; the keep-open lock is gone too (it
    /// lives only in the top bar). Both remain reachable via the menu-bar fallback.
    public var showsTopBar: Bool

    /// Whether the gear and the reachable Settings screen are part of the chrome.
    /// Defaults to `true`. Set to `false` to drop the Settings UI entirely — the gear
    /// is removed, the menu-bar "Settings…" item is dropped, and the expanded
    /// surface stays on the home view.
    public var showsSettings: Bool

    /// The label for the top bar's leading cluster. Defaults to `"Home"` — override
    /// so the bar communicates *product* context (a date, a section name) rather
    /// than the demo's navigation metaphor. The closure receives ``AppState`` for
    /// hosts whose label depends on it.
    ///
    /// `@Sendable` (so a `NookTopBarConfiguration` is `Sendable`) but not
    /// `@MainActor`: this closure derives a label string and touches no main-actor-
    /// only state, so it stays callable from any context.
    public var leadingTitle: @Sendable (AppState) -> String

    /// SF Symbol for the top bar's leading cluster. Defaults to `nil`, which renders
    /// the OpenNook brand mark. Set to `"house"` (or any SF Symbol) to override, or
    /// keep `nil` for title-only on hosts that set a custom title without an icon.
    public var leadingIcon: String?

    /// Host-supplied actions for the top bar's **trailing** cluster, rendered to the
    /// left of the framework's keep-open lock and gear (so the order reads
    /// host items → lock → gear). `nil` (the default) reproduces the framework chrome
    /// exactly — just the lock and gear. Use ``NookConfiguration/setTopBarTrailingItems(_:)``
    /// to set it from a `@ViewBuilder`.
    ///
    /// The items render inside the same chrome environment as the rest of the top bar,
    /// so they can observe ``AppState`` via `@EnvironmentObject` and read the resolved
    /// palette via `@Environment(\.nookResolvedTheme)`.
    ///
    /// > Important: Space is tight. The chrome's top edge sits at the menu-bar level, so
    /// > the top bar runs *under* the physical notch on a notched display — anything
    /// > between the notch's edges is hardware-clipped. The trailing cluster lives to the
    /// > right of the notch, leaving only ~80–100pt of usable width at the 480–520pt
    /// > expanded widths. Host items should be compact glyph-style buttons (matching the
    /// > lock/gear weight), not wide labeled pills.
    ///
    /// `@Sendable @MainActor`: like the other content closures, this builds SwiftUI
    /// views during main-actor rendering and is carried by a `Sendable`
    /// `NookTopBarConfiguration`.
    public var trailingItems: (@Sendable @MainActor () -> AnyView)?

    public init(
        showsTopBar: Bool = true,
        showsSettings: Bool = true,
        leadingTitle: @escaping @Sendable (AppState) -> String = { _ in "Home" },
        leadingIcon: String? = nil,
        trailingItems: (@Sendable @MainActor () -> AnyView)? = nil
    ) {
        self.showsTopBar = showsTopBar
        self.showsSettings = showsSettings
        self.leadingTitle = leadingTitle
        self.leadingIcon = leadingIcon
        self.trailingItems = trailingItems
    }

    /// The framework-demo defaults — top bar on, Settings on, "Home" with the brand mark.
    public static let `default` = NookTopBarConfiguration()
}
