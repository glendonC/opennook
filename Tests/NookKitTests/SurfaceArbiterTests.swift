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
final class SurfaceArbiterTests: XCTestCase {
    /// Drives a `SurfaceArbiter` with fully controllable engagement, active module, and
    /// surface state — no real window. `runSerial` runs operations inline.
    @MainActor
    private final class Harness {
        var engaged = false
        var activeModule = "A"
        var state: NookState = .compact
        private(set) var transitions: [NookState] = []

        lazy var arbiter = SurfaceArbiter(
            isUserEngaged: { self.engaged },
            activeModuleID: { self.activeModule },
            currentState: { self.state },
            runSerial: { operation in await operation() },
            expand: { self.state = .expanded; self.transitions.append(.expanded) },
            compact: { self.state = .compact; self.transitions.append(.compact) },
            hide: { self.state = .hidden; self.transitions.append(.hidden) }
        )
    }

    func testGrantsAndRestoresToPriorState() async {
        let harness = Harness()
        harness.state = .compact

        let token = await harness.arbiter.begin(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNotNil(token)
        XCTAssertEqual(harness.state, .expanded)

        await harness.arbiter.end(token!)
        XCTAssertEqual(harness.state, .compact, "restores to the state captured before the claim")
        XCTAssertFalse(harness.arbiter.isPresenting)
    }

    func testRestoresToHiddenWhenThatWasThePriorState() async {
        let harness = Harness()
        harness.state = .hidden

        let token = await harness.arbiter.begin(NookSurfaceClaim(moduleID: "A"))
        await harness.arbiter.end(token!)

        XCTAssertEqual(harness.state, .hidden)
    }

    func testDeniesWhileUserEngaged() async {
        let harness = Harness()
        harness.engaged = true

        let token = await harness.arbiter.begin(NookSurfaceClaim(moduleID: "A"))
        XCTAssertNil(token, "the user owns the surface while engaging it")
        XCTAssertEqual(harness.state, .compact)
    }

    func testLeavesSurfaceUntouchedWhenUserEngagesDuringPresentation() async {
        let harness = Harness()

        let token = await harness.arbiter.begin(NookSurfaceClaim(moduleID: "A"))
        harness.engaged = true
        await harness.arbiter.end(token!)

        XCTAssertEqual(harness.state, .expanded, "a user who grabbed the surface keeps it")
    }

    func testGatesBackgroundModuleUnlessUrgent() async {
        let harness = Harness()
        harness.activeModule = "A"

        let denied = await harness.arbiter.begin(NookSurfaceClaim(moduleID: "B", priority: .normal))
        XCTAssertNil(denied, "a background module's non-urgent claim is gated out")

        let granted = await harness.arbiter.begin(NookSurfaceClaim(moduleID: "B", priority: .urgent))
        XCTAssertNotNil(granted, "an urgent claim clears the background gate")
    }

    func testEqualPriorityIsDeniedButHigherPreempts() async {
        let harness = Harness()

        let first = await harness.arbiter.begin(NookSurfaceClaim(moduleID: "A", priority: .normal))
        XCTAssertNotNil(first)

        let equal = await harness.arbiter.begin(NookSurfaceClaim(moduleID: "A", priority: .normal))
        XCTAssertNil(equal, "an equal-priority claim does not preempt")

        let higher = await harness.arbiter.begin(NookSurfaceClaim(moduleID: "A", priority: .urgent))
        XCTAssertNotNil(higher, "a strictly higher priority preempts")
    }

    func testSurfaceRestoresOnlyAfterTheLastClaimEnds() async {
        let harness = Harness()
        harness.state = .compact

        let low = await harness.arbiter.begin(NookSurfaceClaim(moduleID: "A", priority: .normal))
        let high = await harness.arbiter.begin(NookSurfaceClaim(moduleID: "A", priority: .urgent))
        XCTAssertNotNil(low)
        XCTAssertNotNil(high)

        // End the preempted (bottom) claim first: a claim still holds the surface.
        await harness.arbiter.end(low!)
        XCTAssertEqual(harness.state, .expanded)
        XCTAssertTrue(harness.arbiter.isPresenting)

        // End the last claim: now the surface restores.
        await harness.arbiter.end(high!)
        XCTAssertEqual(harness.state, .compact)
        XCTAssertFalse(harness.arbiter.isPresenting)
    }
}
