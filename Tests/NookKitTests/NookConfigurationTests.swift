// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI
import XCTest
@testable import NookKit
import NookSurface

// `@MainActor`: the configuration's content and theme closures are main-actor
// isolated (they build SwiftUI views and resolve the chrome palette), so the tests
// that invoke them run on the main actor.
@MainActor
final class NookConfigurationTests: XCTestCase {
    /// The default configuration must reproduce the demo: every content closure is
    /// populated, the theme provider resolves, and no lifecycle hooks are set.
    func testDefaultConfigurationIsComplete() {
        let configuration = NookConfiguration()

        // Content closures are non-optional — invoking them must not trap.
        _ = configuration.home()
        _ = configuration.compactLeading()
        _ = configuration.compactTrailing()
        // Default provider is NookResolvedTheme.live; resolving it must succeed.
        _ = configuration.theme(AppState())

        XCTAssertNil(configuration.onExpand)
        XCTAssertNil(configuration.onCompact)
        XCTAssertNil(configuration.onHide)
    }

    /// A host-supplied theme provider replaces the live one.
    func testCustomThemeProviderIsUsed() {
        let custom = NookResolvedTheme(
            primaryLabel: .red,
            secondaryLabel: .red,
            tertiaryLabel: .red,
            quaternaryLabel: .red,
            subtleFill: .red,
            subtleStroke: .red,
            headerInactiveIcon: .red
        )
        var configuration = NookConfiguration()
        configuration.theme = { _ in custom }

        XCTAssertEqual(configuration.theme(AppState()).primaryLabel, .red)
    }

    /// The coordinator projects the configuration's lifecycle hooks onto the surface
    /// so transitions from any source — host, hover, drag — reach the host.
    @MainActor
    func testCoordinatorProjectsLifecycleHooksOntoTheSurface() {
        var configuration = NookConfiguration()
        configuration.onExpand = {}
        configuration.onCompact = {}
        configuration.onHide = {}

        let coordinator = AppCoordinator(configuration: configuration)

        XCTAssertNotNil(coordinator.surface.onExpand)
        XCTAssertNotNil(coordinator.surface.onCompact)
        XCTAssertNotNil(coordinator.surface.onHide)
    }

    /// With no hooks configured, the surface's callbacks stay nil.
    @MainActor
    func testCoordinatorLeavesHooksNilWhenUnset() {
        let coordinator = AppCoordinator(configuration: NookConfiguration())

        XCTAssertNil(coordinator.surface.onExpand)
        XCTAssertNil(coordinator.surface.onCompact)
        XCTAssertNil(coordinator.surface.onHide)
    }

    /// The default top-bar leading cluster must reproduce the demo: house + "Home".
    func testTopBarLeadingDefaultsMatchTheDemo() {
        let configuration = NookConfiguration()

        XCTAssertEqual(configuration.topBar.leadingIcon, "house")
        XCTAssertEqual(configuration.topBar.leadingTitle(AppState()), "Home")
    }

    /// A host can replace the leading title and drop the icon (e.g. a date-only header).
    func testTopBarLeadingIsHostConfigurable() {
        var configuration = NookConfiguration()
        configuration.topBar.leadingTitle = { _ in "Today" }
        configuration.topBar.leadingIcon = nil

        XCTAssertEqual(configuration.topBar.leadingTitle(AppState()), "Today")
        XCTAssertNil(configuration.topBar.leadingIcon)
    }

    /// The default configuration ships the full framework chrome — top bar and Settings.
    func testDefaultConfigurationEnablesChrome() {
        let configuration = NookConfiguration()

        XCTAssertTrue(configuration.topBar.showsTopBar)
        XCTAssertTrue(configuration.topBar.showsSettings)
    }

    /// A host can switch the top bar and Settings off for a bare expanded surface.
    func testChromeFlagsAreHostConfigurable() {
        var configuration = NookConfiguration()
        configuration.topBar.showsTopBar = false
        configuration.topBar.showsSettings = false

        XCTAssertFalse(configuration.topBar.showsTopBar)
        XCTAssertFalse(configuration.topBar.showsSettings)
    }

    /// With Settings disabled, `showSettings()` must not move the surface off the home
    /// view — there is no Settings UI to show.
    @MainActor
    func testShowSettingsKeepsHomeWhenSettingsDisabled() {
        var configuration = NookConfiguration()
        configuration.topBar.showsSettings = false

        let coordinator = AppCoordinator(configuration: configuration)
        coordinator.showSettings()

        XCTAssertEqual(coordinator.appState.viewMode, .home)
    }

    /// With Settings enabled (the default), `showSettings()` moves to the Settings view.
    @MainActor
    func testShowSettingsEntersSettingsWhenEnabled() {
        let coordinator = AppCoordinator(configuration: NookConfiguration())
        coordinator.showSettings()

        XCTAssertEqual(coordinator.appState.viewMode, .settings)
    }

    // MARK: - Surface customization seams

    /// The default configuration leaves every surface-appearance override unset, so the
    /// framework's own style / animations / width / Settings apply.
    func testDefaultConfigurationHasNoSurfaceOverrides() {
        let configuration = NookConfiguration()
        XCTAssertNil(configuration.style)
        XCTAssertNil(configuration.transitions)
        XCTAssertNil(configuration.expandedWidth)
        XCTAssertNil(configuration.settings)
    }

    /// The framework theme defaults the interaction accent to the system accent and the
    /// chrome font design to `.default`, so the chrome matches the system out of the box.
    func testDefaultThemeAccentAndFontDesignMatchSystem() {
        let theme = NookResolvedTheme.resolve(
            preferences: .default, effectiveColorScheme: .dark, reduceTransparency: false
        )
        XCTAssertEqual(theme.accent, Color(nsColor: .controlAccentColor))
        XCTAssertEqual(theme.fontDesign, .default)
    }

    /// A host palette can override the accent and font design; both round-trip intact.
    func testCustomAccentAndFontDesignArePreserved() {
        let theme = NookResolvedTheme(
            primaryLabel: .white, secondaryLabel: .white, tertiaryLabel: .white,
            quaternaryLabel: .white, subtleFill: .white, subtleStroke: .white,
            headerInactiveIcon: .white, accent: .pink, fontDesign: .rounded
        )
        XCTAssertEqual(theme.accent, .pink)
        XCTAssertEqual(theme.fontDesign, .rounded)
    }

    /// A host-supplied transition configuration replaces the framework defaults on the
    /// surface; `animationDuration` is the observable distinguishing field.
    @MainActor
    func testCustomTransitionsReachTheSurface() {
        var configuration = NookConfiguration()
        configuration.transitions = NookTransitionConfiguration(animationDuration: 1.23)

        let coordinator = AppCoordinator(configuration: configuration)
        coordinator.configureNotchAnimations()

        XCTAssertEqual(coordinator.surface.transitionConfiguration.animationDuration, 1.23)
    }

    /// With no override, the framework's default soft springs apply (non-nil opening
    /// curve, and no custom duration).
    @MainActor
    func testDefaultTransitionsApplyWhenUnset() {
        let coordinator = AppCoordinator(configuration: NookConfiguration())
        coordinator.configureNotchAnimations()

        XCTAssertNotNil(coordinator.surface.transitionConfiguration.openingAnimation)
        XCTAssertNil(coordinator.surface.transitionConfiguration.animationDuration)
    }

    /// `setSettings` installs a host Settings surface; absent it, the slot stays nil so
    /// the built-in Settings UI is used.
    func testSettingsSeamIsHostConfigurable() {
        var configuration = NookConfiguration()
        XCTAssertNil(configuration.settings)

        configuration.setSettings { Text("Custom settings") }
        XCTAssertNotNil(configuration.settings)
        _ = configuration.settings?()
    }
}
