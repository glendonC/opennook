// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookSurface
import XCTest
@testable import NookKit

final class NookAppearancePreferencesTests: XCTestCase {
    func testEffectiveColorSchemeHonorsChromePalette() {
        let prefsDark = NookAppearancePreferences(chromePalette: .dark, surfaceStyle: .translucent)
        XCTAssertEqual(prefsDark.effectiveColorScheme(systemScheme: .light), .dark)

        let prefsLight = NookAppearancePreferences(chromePalette: .light, surfaceStyle: .translucent)
        XCTAssertEqual(prefsLight.effectiveColorScheme(systemScheme: .dark), .light)

        let prefsFollow = NookAppearancePreferences(chromePalette: .followSystem, surfaceStyle: .solid)
        XCTAssertEqual(prefsFollow.effectiveColorScheme(systemScheme: .dark), .dark)
        XCTAssertEqual(prefsFollow.effectiveColorScheme(systemScheme: .light), .light)
    }

    func testRoundTripThroughJSONMatchesDefaults() throws {
        let original = NookAppearancePreferences(
            chromePalette: .light,
            surfaceStyle: .translucent,
            presentation: .floating,
            hapticFeedbackEnabled: true,
            keepNookOpen: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NookAppearancePreferences.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    /// JSON written by an older build can be missing later-added fields. Decoding it must
    /// fill those fields with defaults instead of throwing — otherwise upgrading would
    /// silently reset every saved setting.
    func testDecodeIsForwardCompatibleWithMissingFields() throws {
        let partialJSON = #"{"chromePalette":"dark"}"#
        let data = Data(partialJSON.utf8)
        let decoded = try JSONDecoder().decode(NookAppearancePreferences.self, from: data)

        XCTAssertEqual(decoded.chromePalette, .dark)
        XCTAssertEqual(decoded.surfaceStyle, .solid)    // default
        XCTAssertEqual(decoded.presentation, .auto)     // default
        XCTAssertFalse(decoded.hapticFeedbackEnabled)   // default
        XCTAssertFalse(decoded.keepNookOpen)            // default
    }
}
