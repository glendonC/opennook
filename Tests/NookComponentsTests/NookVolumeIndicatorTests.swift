// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest
@testable import NookComponents

final class NookVolumeIndicatorTests: XCTestCase {
    func testSymbolNameMapsLevels() {
        XCTAssertEqual(NookVolumeIndicator.symbolName(volume: 0.0, isMuted: false), "speaker.fill")
        XCTAssertEqual(NookVolumeIndicator.symbolName(volume: 0.2, isMuted: false), "speaker.wave.1.fill")
        XCTAssertEqual(NookVolumeIndicator.symbolName(volume: 0.5, isMuted: false), "speaker.wave.2.fill")
        XCTAssertEqual(NookVolumeIndicator.symbolName(volume: 0.9, isMuted: false), "speaker.wave.3.fill")
    }

    func testMuteOverridesLevel() {
        XCTAssertEqual(NookVolumeIndicator.symbolName(volume: 1.0, isMuted: true), "speaker.slash.fill")
        XCTAssertEqual(NookVolumeIndicator.symbolName(volume: 0.0, isMuted: true), "speaker.slash.fill")
    }

    /// Smoke test: constructing the observer must not crash, and the reported volume
    /// stays within `0...1` whether or not a real output device is present.
    func testObserverReportsVolumeInRange() {
        let observer = SystemVolumeObserver()
        XCTAssertGreaterThanOrEqual(observer.volume, 0)
        XCTAssertLessThanOrEqual(observer.volume, 1)
    }
}
