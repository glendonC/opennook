// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookSurface
import XCTest
@testable import NookKit

@MainActor
final class AppCoordinatorTests: XCTestCase {
    /// A `NookModule` with distinguishable lifecycle hooks and a switch-away spy.
    private final class SpyModule: NookModule {
        let descriptor: NookModuleDescriptor
        let onExpandTag: String
        private(set) var switchAwayCount = 0
        private(set) var quiesceWork: (@MainActor () async -> Void)?

        /// Where this module records its own `onExpand` firings — shared with the test.
        let expandLog: ExpandLog

        init(id: String, expandLog: ExpandLog, quiesceWork: (@MainActor () async -> Void)? = nil) {
            self.descriptor = NookModuleDescriptor(
                id: id,
                displayName: id,
                backgroundPolicy: .stayResident
            )
            self.onExpandTag = id
            self.expandLog = expandLog
            self.quiesceWork = quiesceWork
        }

        func makeConfiguration() -> NookConfiguration {
            var configuration = NookConfiguration()
            let tag = onExpandTag
            let log = expandLog
            configuration.onExpand = { log.entries.append(tag) }
            return configuration
        }

        func prepareForSwitchAway() async {
            switchAwayCount += 1
            await quiesceWork?()
        }
    }

    /// Reference box so the test and the modules' `onExpand` closures share one log.
    private final class ExpandLog {
        var entries: [String] = []
    }

    private func makeCoordinator(
        modules: [SpyModule],
        surface: FakeNookSurface
    ) -> AppCoordinator {
        var host = NookHostConfiguration()
        for module in modules {
            let captured = module
            host.register(captured.descriptor) { _ in captured }
        }
        host.defaultModule = modules[0].descriptor.id
        let moduleHost = ModuleHost(registry: host.makeRegistry())
        return AppCoordinator(moduleHost: moduleHost, surface: surface)
    }

    /// A switch must observe the surface's LIVE state at execution time. With the
    /// surface expanded, the incoming module gets a synthetic `onExpand`.
    func testSwitchObservesLiveSurfaceState() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let b = SpyModule(id: "B", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a, b], surface: surface)

        await surface.expand(on: nil)
        log.entries.removeAll()  // discard the expand-driven onExpand for module A

        coordinator.switchModule(to: "B")
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(coordinator.activeModuleID, "B")
        XCTAssertEqual(log.entries, ["B"], "synthetic onExpand fires the INCOMING module's hook")
    }

    /// When the surface is not expanded, no synthetic `onExpand` fires.
    func testSwitchWhileCompactFiresNoSyntheticExpand() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let b = SpyModule(id: "B", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a, b], surface: surface)

        await surface.compact(on: nil)
        log.entries.removeAll()

        coordinator.switchModule(to: "B")
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(log.entries, [], "compact surface: no synthetic onExpand")
    }

    /// A switch quiesces the outgoing module before flipping identity.
    func testSwitchQuiescesOutgoingModule() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let b = SpyModule(id: "B", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a, b], surface: surface)

        coordinator.switchModule(to: "B")
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(a.switchAwayCount, 1, "outgoing module was quiesced")
        XCTAssertEqual(b.switchAwayCount, 0, "incoming module is not quiesced")
    }

    /// Switching invalidates the outgoing module's arbiter claims, so its stale token's
    /// `end` becomes a no-op that cannot collapse the incoming module's surface.
    func testSwitchInvalidatesOutgoingModuleClaims() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let b = SpyModule(id: "B", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a, b], surface: surface)

        // Module A takes a transient claim on the surface.
        let token = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNotNil(token)
        XCTAssertEqual(surface.state, .expanded)

        coordinator.switchModule(to: "B")
        await coordinator.drainLifecycleForTesting()

        let transitionsBefore = surface.transitions.count
        // A's drain loop releases its now-stale token: must be a no-op on the surface.
        await coordinator.endTransientPresentation(token!)
        XCTAssertEqual(
            surface.transitions.count, transitionsBefore,
            "a switched-away module's stale end must not move the surface"
        )
    }

    /// Switch transactions serialize on the lifecycle chain: two back-to-back switches
    /// resolve in order, settling on the last requested module.
    func testSwitchesSerializeOnLifecycleChain() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let b = SpyModule(id: "B", expandLog: log)
        let c = SpyModule(id: "C", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a, b, c], surface: surface)

        // Make A's quiesce slow, so if switches were not serialized the B→C switch
        // could interleave with the A→B transaction.
        coordinator.switchModule(to: "B")
        coordinator.switchModule(to: "C")
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(coordinator.activeModuleID, "C", "the last switch wins, in order")
        XCTAssertEqual(a.switchAwayCount, 1)
        XCTAssertEqual(b.switchAwayCount, 1, "B was switched away from after A→B settled")
    }

    /// Switching to the already-active module is a no-op.
    func testSwitchToActiveModuleIsNoOp() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)

        coordinator.switchModule(to: "A")
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(a.switchAwayCount, 0)
        XCTAssertEqual(coordinator.activeModuleID, "A")
    }
}
