// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookSurface
import SwiftUI
import XCTest
@testable import NookKit

/// Host-global chrome behavior: hover side-effects, the cold-launch shimmer opt-out, and
/// the appearance→backdrop mapping override — all defaulting to today's behavior and
/// threaded from the host (or, single-module, forwarded from `NookConfiguration`).
///
/// `@MainActor`: `AppCoordinator` / `ModuleHost` are main-actor isolated.
@MainActor
final class NookChromeBehaviorTests: XCTestCase {
    private func makeCoordinator(
        chromeBehavior: NookChromeBehavior,
        appState: AppState = AppState(),
        surface: FakeNookSurface
    ) -> AppCoordinator {
        var host = NookHostConfiguration()
        host.chromeBehavior = chromeBehavior
        host.register(NookModuleDescriptor(id: "A", displayName: "A")) { NookConfiguration() }
        host.defaultModule = "A"
        return AppCoordinator(
            appState: appState,
            moduleHost: ModuleHost(registry: host.makeRegistry()),
            surface: surface
        )
    }

    /// Defaults reproduce the framework: no hover side-effects, the shimmer plays, and no
    /// backdrop override — and both configuration structs default to that.
    func testDefaultsReproduceFramework() {
        let behavior = NookChromeBehavior.default
        XCTAssertEqual(behavior.hoverBehavior, [])
        XCTAssertTrue(behavior.showsLaunchShimmer)
        XCTAssertNil(behavior.backdrop)

        XCTAssertEqual(NookConfiguration().chromeBehavior.hoverBehavior, [])
        XCTAssertTrue(NookConfiguration().chromeBehavior.showsLaunchShimmer)
        XCTAssertNil(NookConfiguration().chromeBehavior.backdrop)

        XCTAssertEqual(NookHostConfiguration().chromeBehavior.hoverBehavior, [])
        XCTAssertTrue(NookHostConfiguration().chromeBehavior.showsLaunchShimmer)
    }

    /// The host's chrome behavior reaches `ModuleHost` (the path `AppCoordinator` reads).
    func testChromeBehaviorThreadsFromHostToModuleHost() {
        var host = NookHostConfiguration()
        host.chromeBehavior = NookChromeBehavior(
            hoverBehavior: .all,
            showsLaunchShimmer: false,
            backdrop: { _, _, _ in .solid(.red) }
        )
        host.register(NookModuleDescriptor(id: "A", displayName: "A")) { NookConfiguration() }

        let moduleHost = ModuleHost(registry: host.makeRegistry())

        XCTAssertEqual(moduleHost.chromeBehavior.hoverBehavior, .all)
        XCTAssertFalse(moduleHost.chromeBehavior.showsLaunchShimmer)
        XCTAssertNotNil(moduleHost.chromeBehavior.backdrop)
    }

    /// The single-module path forwards `NookConfiguration.chromeBehavior` onto the
    /// synthesized host.
    func testSingleModuleForwardsChromeBehavior() {
        var configuration = NookConfiguration()
        configuration.chromeBehavior.hoverBehavior = .keepVisible

        let moduleHost = ModuleHost(configuration: configuration)

        XCTAssertEqual(moduleHost.chromeBehavior.hoverBehavior, .keepVisible)
    }

    /// A host backdrop resolver replaces the framework mapping on the surface.
    func testBackdropOverrideReachesSurface() {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(
            chromeBehavior: NookChromeBehavior(backdrop: { _, _, _ in .solid(.red) }),
            surface: surface
        )

        coordinator.syncNotchBackdrop()

        XCTAssertEqual(surface.backdrop, .solid(.red))
    }

    /// Without an override, the framework mapping applies — a `.dark` + `.solid`
    /// appearance maps to opaque black regardless of the system scheme.
    func testDefaultBackdropUsesFrameworkMapping() {
        let appState = AppState()
        appState.appearancePreferences = NookAppearancePreferences(
            chromePalette: .dark,
            surfaceStyle: .solid
        )
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(
            chromeBehavior: .default,
            appState: appState,
            surface: surface
        )

        coordinator.syncNotchBackdrop()

        XCTAssertEqual(surface.backdrop, .solid(.black))
    }

    /// With the shimmer opted out, cold launch fires no feedback (but still settles the
    /// surface into its compact launch state).
    func testLaunchShimmerOptOutPlaysNoFeedback() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(
            chromeBehavior: NookChromeBehavior(showsLaunchShimmer: false),
            surface: surface
        )

        coordinator.start()
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(surface.feedbackCount, 0)
        XCTAssertEqual(surface.state, .compact)
    }

    /// By default the cold-launch shimmer plays exactly once.
    func testLaunchShimmerPlaysByDefault() async {
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(chromeBehavior: .default, surface: surface)

        coordinator.start()
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(surface.feedbackCount, 1)
    }
}
