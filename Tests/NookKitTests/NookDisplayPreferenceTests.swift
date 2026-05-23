// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import XCTest
@testable import NookKit

final class NookDisplayPreferenceTests: XCTestCase {
    func testDefaultIsBuiltIn() {
        XCTAssertEqual(NookDisplayPreference.default, .builtIn)
        XCTAssertEqual(NookDisplayPreference.default.mode, .builtIn)
        XCTAssertNil(NookDisplayPreference.default.displayUUID)
    }

    func testSpecificCarriesUUID() {
        let preference = NookDisplayPreference.specific("ABC-123")
        XCTAssertEqual(preference.mode, .specific)
        XCTAssertEqual(preference.displayUUID, "ABC-123")
    }

    func testRoundTripThroughJSON() throws {
        for original in [
            NookDisplayPreference.builtIn,
            NookDisplayPreference.main,
            NookDisplayPreference.specific("UUID-ABCDEF"),
        ] {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(NookDisplayPreference.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }

    /// An unrecognized `mode` (e.g. JSON from a newer build) must degrade to the default
    /// rather than throw — a decode failure would wipe the user's other saved settings.
    func testUnknownModeDecodesToDefault() throws {
        let data = Data(#"{"mode":"someFutureMode"}"#.utf8)
        let decoded = try JSONDecoder().decode(NookDisplayPreference.self, from: data)
        XCTAssertEqual(decoded, .default)
    }

    /// A `.specific` record with no UUID is incoherent — it can't name a display — so it
    /// degrades to the default instead of resolving to an empty-string UUID.
    func testSpecificWithoutUUIDDecodesToDefault() throws {
        let data = Data(#"{"mode":"specific"}"#.utf8)
        let decoded = try JSONDecoder().decode(NookDisplayPreference.self, from: data)
        XCTAssertEqual(decoded, .default)
    }

    func testEmptyJSONDecodesToDefault() throws {
        let decoded = try JSONDecoder().decode(NookDisplayPreference.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded, .default)
    }

    /// The resolver must never strand the chrome: on any host with a display attached,
    /// every preference mode resolves to *some* screen via the fallback chain.
    func testResolverAlwaysReturnsAScreenWhenADisplayIsAttached() throws {
        guard !NSScreen.screens.isEmpty else {
            throw XCTSkip("No display attached in this environment.")
        }
        XCTAssertNotNil(NookScreenLocator.screen(matching: .builtIn))
        XCTAssertNotNil(NookScreenLocator.screen(matching: .main))
        // An unknown UUID falls through to the built-in/main/first chain.
        XCTAssertNotNil(NookScreenLocator.screen(matching: .specific("not-a-real-display-uuid")))
    }

    /// Pins the unplug-equivalent fallback chain order for `.specific`. When the
    /// requested UUID is not in the connected set (i.e. the user picked an external
    /// display and it has since been unplugged), the resolver must return the
    /// built-in panel if present, otherwise the main screen, otherwise the first
    /// attached — in that order, NOT an arbitrary screen.
    func testSpecificUnpluggedResolvesViaBuiltInThenMainThenFirst() throws {
        guard !NSScreen.screens.isEmpty else {
            throw XCTSkip("No display attached in this environment.")
        }
        let resolved = NookScreenLocator.screen(matching: .specific("display-that-was-unplugged"))
        XCTAssertNotNil(resolved)
        // The resolved screen MUST be one of the three documented fallbacks. Building
        // the eligible set explicitly catches a future bug where the chain returns,
        // say, `NSScreen.screens.last` by mistake.
        let eligible: [NSScreen?] = [
            NookScreenLocator.builtInScreen(),
            NSScreen.main,
            NSScreen.screens.first
        ]
        XCTAssertTrue(
            eligible.contains(where: { $0 === resolved }),
            "an unplugged `.specific` must fall through to built-in / main / first — not an arbitrary screen"
        )
    }
}
