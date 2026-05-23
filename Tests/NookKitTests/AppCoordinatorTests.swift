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

    /// A switch quiesces the outgoing module. With the reordered switch, the quiesce
    /// runs off the lifecycle chain — `drainSwitchTailsForTesting()` joins it.
    func testSwitchQuiescesOutgoingModule() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let b = SpyModule(id: "B", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a, b], surface: surface)

        coordinator.switchModule(to: "B")
        await coordinator.drainLifecycleForTesting()
        await coordinator.drainSwitchTailsForTesting()

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
    /// resolve in order, settling on the last requested module. The off-chain quiesce
    /// drains are joined separately via `drainSwitchTailsForTesting()`.
    func testSwitchesSerializeOnLifecycleChain() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let b = SpyModule(id: "B", expandLog: log)
        let c = SpyModule(id: "C", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a, b, c], surface: surface)

        coordinator.switchModule(to: "B")
        coordinator.switchModule(to: "C")
        await coordinator.drainLifecycleForTesting()
        await coordinator.drainSwitchTailsForTesting()

        XCTAssertEqual(coordinator.activeModuleID, "C", "the last switch wins, in order")
        XCTAssertEqual(a.switchAwayCount, 1)
        XCTAssertEqual(b.switchAwayCount, 1, "B was switched away from after A→B settled")
    }

    /// Regression: a misbehaving outgoing module whose `prepareForSwitchAway` never
    /// returns must NOT wedge the lifecycle chain. Before the reorder, performSwitch
    /// awaited the quiesce on-chain and a hang in module code froze every queued
    /// surface transition behind it.
    func testSwitchDoesNotWedgeOnHangingPrepareForSwitchAway() async {
        let log = ExpandLog()
        // A's quiesce parks forever — simulating a misbehaving module.
        let a = SpyModule(id: "A", expandLog: log, quiesceWork: {
            try? await Task.sleep(for: .seconds(60))
        })
        let b = SpyModule(id: "B", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a, b], surface: surface)

        coordinator.switchModule(to: "B")
        // The lifecycle chain settles immediately even though A's quiesce is parked.
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(
            coordinator.activeModuleID, "B",
            "switch identity flips on the serial chain — hanging quiesce drains off-chain"
        )
        // Module B's hooks are live; we can drive the surface without waiting for A.
        let token = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "B"))
        XCTAssertNotNil(token, "lifecycle chain unwedged — new claims still flow")
    }

    /// `registerGlobalHotkey` records its outcome on the durable failure channel.
    /// A successful registration leaves no `"toggle"` failure entry, and — critically —
    /// a pre-existing failure entry is cleared once a registration succeeds.
    func testRegisterGlobalHotkeyClearsFailureOnSuccess() {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)

        // Seed a stale failure as if a previous registration had failed.
        coordinator.appState.recordHotkeyRegistration(
            id: "toggle",
            failure: HotkeyRegistrationFailure(shortcutName: "Show Nook", combination: "⌥⌘;")
        )
        XCTAssertNotNil(coordinator.appState.hotkeyRegistrationFailures["toggle"])

        coordinator.registerGlobalHotkey()

        // The default hotkey registers cleanly, so the seeded failure is cleared.
        XCTAssertNil(
            coordinator.appState.hotkeyRegistrationFailures["toggle"],
            "a successful global-hotkey registration clears the prior failure"
        )
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

    // MARK: - User-engagement model

    /// Drains the lifecycle chain and yields the main actor long enough for any
    /// `.receive(on: RunLoop.main)` sinks (notably `bindSurfaceVisibility`, which
    /// updates `appState.isNookVisible` and clears `userInitiatedOpen` on collapse)
    /// to observe the latest surface state before the next assertion runs.
    ///
    /// `Task.sleep` yields the main-actor executor so RunLoop.main can deliver any
    /// pending `.receive(on:)` sinks; a bare `Task.yield()` does not interleave with
    /// the runloop the way these sinks are scheduled on.
    private func drainAndPump(_ coordinator: AppCoordinator) async {
        await coordinator.drainLifecycleForTesting()
        try? await Task.sleep(nanoseconds: 30_000_000)  // 30 ms — generous on CI
    }

    /// REGRESSION: the arbiter's own `expand()` must NOT trip `isUserEngaged`. Before
    /// the fix, `isUserEngaged` read `appState.isNookVisible`, which mirrored the
    /// surface and flipped `true` as soon as the arbiter expanded — silently disabling
    /// all subsequent preemption. After the fix, engagement reads from explicit user
    /// intent, so the arbiter's expand leaves it `false`.
    func testArbiterExpandDoesNotMarkUserEngaged() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)

        let token = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNotNil(token, "arbiter granted the claim")
        XCTAssertEqual(surface.state, .expanded, "the arbiter expanded the surface")

        await drainAndPump(coordinator)

        XCTAssertFalse(
            coordinator.isUserEngaged,
            "an arbiter-driven expand must not be read as user engagement — that was the bug"
        )
    }

    /// REGRESSION: a strictly-higher-priority claim must preempt an in-flight lower-
    /// priority claim, *across* the `RunLoop.main` mirror hop. Before the fix, after
    /// the mirror flipped the second `begin()` would deny on the user-engaged branch
    /// before the priority check even ran.
    func testHigherPriorityClaimPreemptsAcrossMirrorHop() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)

        let normal = await coordinator.beginTransientPresentation(
            NookSurfaceClaim(moduleID: "A", priority: .normal)
        )
        XCTAssertNotNil(normal)
        await drainAndPump(coordinator)  // let the mirror flip — this is what hid the bug

        let urgent = await coordinator.beginTransientPresentation(
            NookSurfaceClaim(moduleID: "A", priority: .urgent)
        )
        XCTAssertNotNil(
            urgent,
            "an urgent claim must preempt a normal one even after the visibility mirror has propagated"
        )
    }

    /// A user-initiated `showNook` marks engagement, and a transient claim is denied
    /// for the duration of that engagement.
    func testUserShowNookMarksEngagedAndBlocksTransient() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)

        coordinator.showNook()
        await coordinator.drainLifecycleForTesting()

        XCTAssertTrue(coordinator.isUserEngaged, "the user opened the surface — they own it")

        let token = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNil(token, "a claim must be denied while the user owns the surface")
    }

    /// `hideNook` clears the user-open intent and a transient claim can then be granted.
    func testHideNookClearsEngagement() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)

        coordinator.showNook()
        await coordinator.drainLifecycleForTesting()
        XCTAssertTrue(coordinator.isUserEngaged)

        coordinator.hideNook()
        await drainAndPump(coordinator)
        XCTAssertFalse(coordinator.isUserEngaged, "hideNook clears the user-open intent")

        let token = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNotNil(token, "with the user gone, a transient claim is granted")
    }

    /// If the surface collapses independently (hover-exit auto-compact, simulated here
    /// by a direct `compact(on:)`), the `bindSurfaceVisibility` sink clears the user-
    /// open intent — so the arbiter is willing to grant the next claim.
    func testHoverExitAutoCompactClearsUserOpenIntent() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)

        coordinator.showNook()
        await coordinator.drainLifecycleForTesting()
        XCTAssertTrue(coordinator.isUserEngaged)

        // Simulate hover-exit auto-compact: the surface drops to `.compact` without
        // any coordinator call. The mirror sink is responsible for clearing intent.
        await surface.compact(on: nil)
        await drainAndPump(coordinator)

        XCTAssertFalse(
            coordinator.isUserEngaged,
            "an independent collapse must clear the user-open intent via the mirror sink"
        )

        let token = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNotNil(token, "a transient claim is grantable after the user's nook collapsed")
    }

    /// Hover engagement counts even when the user did not open the surface — i.e.,
    /// `userInitiatedOpen` is unset but `isHovering` is true.
    func testHoveringBlocksTransientEvenWithoutUserOpen() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)

        surface.isHovering = true
        XCTAssertTrue(coordinator.isUserEngaged, "hover alone is engagement")

        let denied = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNil(denied, "hover blocks a transient claim")

        surface.isHovering = false
        let granted = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNotNil(granted, "with hover gone, the claim is granted")
    }

    /// Arbiter restore-on-last-end must not leave stale user-open intent behind: after
    /// the last claim ends and the arbiter restores the surface to compact, a fresh
    /// claim is grantable on the next attempt.
    func testArbiterRestoreDoesNotLeaveStaleUserOpenIntent() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)

        let token = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNotNil(token)
        await drainAndPump(coordinator)

        await coordinator.endTransientPresentation(token!)
        await drainAndPump(coordinator)

        XCTAssertFalse(coordinator.isUserEngaged, "arbiter restore leaves no stale engagement")

        let again = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNotNil(again, "the surface is grantable again after the previous claim restored")
    }

    /// Contract: engagement that *begins* after a claim is granted does NOT preempt
    /// the active claim. The presenter is responsible for yielding (see
    /// ``NookActivityQueue``'s `waitWhileUserEngaged`). This test pins the begin-gate-
    /// only semantics so a future change can't silently introduce mid-claim eviction.
    func testEngagementMidClaimDoesNotPreemptActiveClaim() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)

        let token = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNotNil(token)
        XCTAssertEqual(surface.state, .expanded)

        // The user starts hovering AFTER the claim is granted.
        surface.isHovering = true
        XCTAssertTrue(coordinator.isUserEngaged)

        // The surface is still expanded — the arbiter does not force-end mid-claim.
        XCTAssertEqual(
            surface.state, .expanded,
            "mid-claim engagement does NOT preempt — the presenter must yield itself"
        )

        // A NEW claim, however, is denied — engagement gates `begin`.
        let denied = await coordinator.beginTransientPresentation(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNil(denied, "a new claim is denied while the user is now engaged")

        // Ending the original token while the user is engaged leaves the surface as-is
        // (the arbiter's `end` skips restore when `isUserEngaged()` is true).
        await coordinator.endTransientPresentation(token!)
        await coordinator.drainLifecycleForTesting()
        XCTAssertEqual(
            surface.state, .expanded,
            "end-during-engagement leaves the user's state alone (no restore)"
        )
    }

    // MARK: - viewMode coherence across module switch

    /// Regression: switching to a module whose `topBar.showsSettings == false` must drop
    /// any stranded `viewMode == .settings`. Without this, the chrome's top bar reads a
    /// settings-mode viewMode and renders a back-chevron at a Settings screen that
    /// `NookExpandedView` correctly refuses to mount — the user sees a phantom nav target.
    func testSwitchToModuleWithSettingsDisabledClearsStrandedSettingsViewMode() async {
        final class SettingsHidingModule: NookModule {
            let descriptor: NookModuleDescriptor
            init(id: String) {
                descriptor = NookModuleDescriptor(id: id, displayName: id, backgroundPolicy: .stayResident)
            }
            func makeConfiguration() -> NookConfiguration {
                var configuration = NookConfiguration()
                configuration.topBar.showsSettings = false
                return configuration
            }
            func prepareForSwitchAway() async {}
        }

        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)  // showsSettings == true (default)
        let b = SettingsHidingModule(id: "B")
        let surface = FakeNookSurface()

        var host = NookHostConfiguration()
        let aRef = a
        host.register(aRef.descriptor) { _ in aRef }
        let bRef = b
        host.register(bRef.descriptor) { _ in bRef }
        host.defaultModule = "A"
        let coordinator = AppCoordinator(
            moduleHost: ModuleHost(registry: host.makeRegistry()),
            surface: surface
        )

        // User opens Settings while on A — viewMode strands to .settings.
        coordinator.appState.showSettings()
        XCTAssertEqual(coordinator.appState.viewMode, .settings)

        coordinator.switchModule(to: "B")
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(coordinator.activeModuleID, "B")
        XCTAssertEqual(
            coordinator.appState.viewMode, .home,
            "incoming module disables Settings — viewMode must snap to .home"
        )
    }

    /// Counter: switching to a module that *also* allows Settings must NOT touch a
    /// `.settings` viewMode. The fix is narrow — only clear when the incoming module
    /// disables the Settings screen.
    func testSwitchPreservesSettingsViewModeWhenIncomingModuleAllowsIt() async {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let b = SpyModule(id: "B", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a, b], surface: surface)

        coordinator.appState.showSettings()
        XCTAssertEqual(coordinator.appState.viewMode, .settings)

        coordinator.switchModule(to: "B")
        await coordinator.drainLifecycleForTesting()

        XCTAssertEqual(
            coordinator.appState.viewMode, .settings,
            "incoming module still allows Settings — viewMode preserved"
        )
    }

    // MARK: - Hotkey registration intent dedup

    /// Regression: a recording-finished event flips both `$hotkey` and
    /// `$isRecordingHotkey` on the same runloop turn. The sink used to react to each
    /// upstream emission separately, recording the registration outcome twice on the
    /// durable failure channel and minting two fresh Carbon ids per rebind. Mapping the
    /// combineLatest pair onto a `HotkeyRegistrationIntent` collapses the two emissions
    /// onto one *intent change* (suspended → bound), and `removeDuplicates` then dedups
    /// transitional duplicates.
    func testHotkeyRebindFiresExactlyOneRegisterPerUserAction() async throws {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)
        coordinator.registerGlobalHotkey()  // initial registration (start()'s job)
        coordinator.bindHotkeyRegistration()  // install the sink
        let mintedAfterStart = coordinator.hotkeyController.carbonIDsMintedForTesting

        // Open the recorder — intent maps to `.suspended`; sink unregisters (no mint).
        coordinator.appState.isRecordingHotkey = true
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertEqual(
            coordinator.hotkeyController.carbonIDsMintedForTesting, mintedAfterStart,
            "unregister mints nothing"
        )

        // User picks a new hotkey, then closes the recorder. Both publishes happen on
        // the same runloop turn — the sink must fire exactly ONE register for the new
        // hotkey, not one per upstream @Published change.
        let newHotkey = NookHotkey(keyCode: 51, carbonModifiers: 4096 | 2048, keySymbol: "⌫")
        coordinator.appState.replaceHotkey(newHotkey)
        coordinator.appState.isRecordingHotkey = false
        try await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertEqual(
            coordinator.hotkeyController.carbonIDsMintedForTesting,
            mintedAfterStart + 1,
            "one register per user action, not one per upstream @Published change"
        )
        XCTAssertTrue(coordinator.hotkeyController.registeredIDsForTesting.contains(NookHotkeyIDs.toggle))
    }

    /// Recorder opened and then cancelled without changing the key collapses through
    /// `.suspended` → `.bound(unchanged)` — exactly one restore registration after the
    /// unregister.
    // MARK: - Cold-launch onCompact suppression

    /// Regression: the cold-launch compact in `start()` is a boot artifact, not a
    /// user-driven dismiss. A host wiring `onCompact = { /* user collapsed */ }`
    /// must not see that hook fire on launch. The fix nils onCompact for the
    /// duration of the cold-launch compact and restores it before any further
    /// transition can run.
    func testColdLaunchCompactDoesNotFireHostOnCompact() async throws {
        final class CompactCountingModule: NookModule {
            let descriptor: NookModuleDescriptor
            let counter: Counter
            init(id: String, counter: Counter) {
                self.descriptor = NookModuleDescriptor(id: id, displayName: id, backgroundPolicy: .stayResident)
                self.counter = counter
            }
            func makeConfiguration() -> NookConfiguration {
                var configuration = NookConfiguration()
                let c = counter
                configuration.onCompact = { c.value += 1 }
                return configuration
            }
            func prepareForSwitchAway() async {}
        }
        final class Counter { var value = 0 }

        let counter = Counter()
        let module = CompactCountingModule(id: "A", counter: counter)
        let surface = FakeNookSurface()
        var host = NookHostConfiguration()
        let m = module
        host.register(m.descriptor) { _ in m }
        host.defaultModule = "A"
        let coordinator = AppCoordinator(
            moduleHost: ModuleHost(registry: host.makeRegistry()),
            surface: surface
        )

        coordinator.start()
        await coordinator.drainLifecycleForTesting()
        XCTAssertEqual(counter.value, 0, "cold-launch compact did not fire host onCompact")
        XCTAssertEqual(surface.state, .compact, "but the surface IS compact")

        // A subsequent user-driven compact fires it normally — the suppression is
        // strictly for the boot transition.
        await surface.expand(on: nil)
        await surface.compact(on: nil)
        XCTAssertEqual(counter.value, 1, "post-boot compact fires onCompact normally")
    }

    func testHotkeyRecorderOpenedAndCancelledIsBoundedRoundTrip() async throws {
        let log = ExpandLog()
        let a = SpyModule(id: "A", expandLog: log)
        let surface = FakeNookSurface()
        let coordinator = makeCoordinator(modules: [a], surface: surface)
        coordinator.registerGlobalHotkey()
        coordinator.bindHotkeyRegistration()
        let mintedAfterStart = coordinator.hotkeyController.carbonIDsMintedForTesting

        coordinator.appState.isRecordingHotkey = true
        try await Task.sleep(nanoseconds: 30_000_000)
        coordinator.appState.isRecordingHotkey = false
        try await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertEqual(
            coordinator.hotkeyController.carbonIDsMintedForTesting,
            mintedAfterStart + 1,
            "open + cancel recorder fires one restore registration"
        )
    }
}
