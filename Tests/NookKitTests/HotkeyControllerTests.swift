// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Carbon
import XCTest
@testable import NookKit

/// Bookkeeping coverage for ``HotkeyController``. The Carbon-level
/// `RegisterEventHotKey` call may or may not succeed depending on the test
/// environment (an XCTest binary often lacks a proper app context), but the
/// controller's own dispatch table — what `register`/`unregister`/`unregisterAll`
/// keep — is fully observable through the internal test seam and is what these
/// tests pin. The Carbon-event delivery path itself is integration-tested by
/// `AppCoordinatorTests`' real hotkey registration.
@MainActor
final class HotkeyControllerTests: XCTestCase {
    /// Carbon key code for "F19" — a function key that almost certainly isn't bound,
    /// and is unlikely to fire while tests run.
    private let f19KeyCode: UInt32 = 80

    /// Carbon key code for "F20".
    private let f20KeyCode: UInt32 = 90

    func testRegisterRecordsTheID() {
        let controller = HotkeyController()
        _ = controller.register("toggle", keyCode: f19KeyCode, modifiers: UInt32(cmdKey | optionKey)) {}
        XCTAssertTrue(controller.registeredIDsForTesting.contains("toggle"))
    }

    func testRegisterTwoDistinctIDsAreBothRecorded() {
        let controller = HotkeyController()
        _ = controller.register("toggle", keyCode: f19KeyCode, modifiers: UInt32(cmdKey | optionKey)) {}
        _ = controller.register("cycle", keyCode: f20KeyCode, modifiers: UInt32(cmdKey | optionKey)) {}
        XCTAssertEqual(controller.registeredIDsForTesting, ["toggle", "cycle"])
    }

    /// Re-registering an existing id replaces the prior registration in place — and
    /// mints a FRESH Carbon hotkey id so a stale Carbon event in flight from the
    /// old binding cannot resolve to the new handler.
    func testRegisterReplacingSameIDMintsFreshCarbonID() {
        let controller = HotkeyController()
        _ = controller.register("toggle", keyCode: f19KeyCode, modifiers: UInt32(cmdKey)) {}
        let firstMinted = controller.carbonIDsMintedForTesting

        _ = controller.register("toggle", keyCode: f19KeyCode, modifiers: UInt32(cmdKey | optionKey)) {}
        let secondMinted = controller.carbonIDsMintedForTesting

        XCTAssertEqual(
            controller.registeredIDsForTesting, ["toggle"],
            "the same id stays a single registration"
        )
        XCTAssertGreaterThan(
            secondMinted, firstMinted,
            "re-registering must mint a fresh Carbon id, not reuse the prior one"
        )
    }

    /// Re-registering also REPLACES the dispatched handler — so a stale handler
    /// from the previous registration cannot fire under the same id.
    func testRegisterReplacingSameIDReplacesDispatchedHandler() {
        let controller = HotkeyController()
        var oldFireCount = 0
        var newFireCount = 0

        _ = controller.register("toggle", keyCode: f19KeyCode, modifiers: UInt32(cmdKey)) {
            oldFireCount += 1
        }
        _ = controller.register("toggle", keyCode: f19KeyCode, modifiers: UInt32(cmdKey)) {
            newFireCount += 1
        }

        XCTAssertTrue(controller.fireForTesting(id: "toggle"))
        XCTAssertEqual(oldFireCount, 0, "the prior handler must NOT fire after replacement")
        XCTAssertEqual(newFireCount, 1, "the new handler is what runs")
    }

    func testUnregisterDropsTheID() {
        let controller = HotkeyController()
        _ = controller.register("toggle", keyCode: f19KeyCode, modifiers: UInt32(cmdKey)) {}
        XCTAssertTrue(controller.registeredIDsForTesting.contains("toggle"))

        controller.unregister("toggle")
        XCTAssertFalse(controller.registeredIDsForTesting.contains("toggle"))
    }

    /// Unregistering an unknown id is a no-op — does not throw, does not affect siblings.
    func testUnregisterUnknownIDIsNoOp() {
        let controller = HotkeyController()
        _ = controller.register("toggle", keyCode: f19KeyCode, modifiers: UInt32(cmdKey)) {}

        controller.unregister("never-registered")
        XCTAssertEqual(controller.registeredIDsForTesting, ["toggle"])
    }

    func testUnregisterAllClearsEverything() {
        let controller = HotkeyController()
        _ = controller.register("a", keyCode: f19KeyCode, modifiers: UInt32(cmdKey)) {}
        _ = controller.register("b", keyCode: f20KeyCode, modifiers: UInt32(cmdKey)) {}
        XCTAssertEqual(controller.registeredIDsForTesting.count, 2)

        controller.unregisterAll()
        XCTAssertTrue(controller.registeredIDsForTesting.isEmpty)
    }

    /// `fireForTesting` proves the dispatch table is wired by id: a press for an
    /// unregistered id is a no-op.
    func testFireForUnregisteredIDIsNoOp() {
        let controller = HotkeyController()
        XCTAssertFalse(controller.fireForTesting(id: "ghost"))
    }
}
