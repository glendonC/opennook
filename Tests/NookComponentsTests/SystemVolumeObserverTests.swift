// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import CoreAudio
import XCTest
@testable import NookComponents

/// A fully controllable ``VolumeReading`` — no live audio device. Lets the tests drive
/// the default-device, volume, and mute reads deterministically.
///
/// `@unchecked Sendable` so a test can mutate it after the observer has captured it.
/// That is sound here: the observer only reads through it on the main actor, and the
/// tests are `@MainActor` too — there is no real concurrency.
private final class FakeVolumeReader: VolumeReading, @unchecked Sendable {
    var device: AudioDeviceID? = AudioDeviceID(1)
    var volume: Double? = 0.5
    var muted = false

    func defaultOutputDevice() -> AudioDeviceID? { device }
    func readVolume(_ device: AudioDeviceID) -> Double? { volume }
    func readMute(_ device: AudioDeviceID) -> Bool { muted }
}

final class SystemVolumeObserverTests: XCTestCase {

    // MARK: - resolveVolumeFallback (pure: main-element vs per-channel average)

    func testFallbackPrefersMainElementScalar() {
        // A main-element scalar wins outright — channel scalars are ignored.
        XCTAssertEqual(resolveVolumeFallback(mainScalar: 0.4, channelScalars: [0.1, 0.9]), 0.4)
    }

    func testFallbackAveragesPerChannelWhenNoMainElement() {
        // No main scalar: average whatever per-channel scalars resolved.
        XCTAssertEqual(resolveVolumeFallback(mainScalar: nil, channelScalars: [0.2, 0.8]), 0.5)
    }

    func testFallbackAveragesSingleChannel() {
        XCTAssertEqual(resolveVolumeFallback(mainScalar: nil, channelScalars: [0.3]), 0.3)
    }

    func testFallbackReturnsNilWhenNothingAvailable() {
        // Neither a main scalar nor any channel scalar — unreadable.
        XCTAssertNil(resolveVolumeFallback(mainScalar: nil, channelScalars: []))
    }

    // MARK: - Observer reads through the injected seam

    @MainActor
    func testObserverReadsVolumeAndMuteFromReader() {
        let reader = FakeVolumeReader()
        reader.volume = 0.42
        reader.muted = true
        let observer = SystemVolumeObserver(reader: reader)

        XCTAssertEqual(observer.volume, 0.42)
        XCTAssertTrue(observer.isMuted)
    }

    @MainActor
    func testObserverReadsUnmutedState() {
        let reader = FakeVolumeReader()
        reader.muted = false
        XCTAssertFalse(SystemVolumeObserver(reader: reader).isMuted)
    }

    @MainActor
    func testObserverClampsVolumeIntoUnitRange() {
        // A reader reporting an out-of-range value (a quirky device, a stale read) must
        // not leak past `0...1` — the observer clamps before publishing.
        let high = FakeVolumeReader()
        high.volume = 1.7
        XCTAssertEqual(SystemVolumeObserver(reader: high).volume, 1.0)

        let low = FakeVolumeReader()
        low.volume = -0.3
        XCTAssertEqual(SystemVolumeObserver(reader: low).volume, 0.0)
    }

    @MainActor
    func testObserverReportsZeroWhenNoDefaultDevice() {
        // No default output device available — the observer reports a silent, unmuted
        // baseline rather than stale state.
        let reader = FakeVolumeReader()
        reader.device = nil
        reader.volume = 0.9
        reader.muted = true
        let observer = SystemVolumeObserver(reader: reader)

        XCTAssertEqual(observer.volume, 0)
        XCTAssertFalse(observer.isMuted)
    }

    @MainActor
    func testObserverRebindsToNewDefaultDevice() {
        // Bind to a device with a known level, then swap the default device out from
        // under the observer and trigger a rebind — it must follow the new device.
        let reader = FakeVolumeReader()
        reader.device = AudioDeviceID(1)
        reader.volume = 0.25
        let observer = SystemVolumeObserver(reader: reader)
        XCTAssertEqual(observer.volume, 0.25)

        // Default output device changes (headphones plugged in, output switched).
        reader.device = AudioDeviceID(2)
        reader.volume = 0.75
        observer.rebindForTesting()
        XCTAssertEqual(observer.volume, 0.75, "rebind must re-read from the new default device")

        // Default device disappears entirely.
        reader.device = nil
        observer.rebindForTesting()
        XCTAssertEqual(observer.volume, 0, "losing the default device resets to a silent baseline")
    }

    // MARK: - CoreAudio listener add/remove balance

    /// Every `AudioObjectAddPropertyListenerBlock` call the observer makes must be
    /// paired with a `AudioObjectRemovePropertyListenerBlock`. The observer's
    /// `deinit` does this for the lifetime case; `tearDownForTesting()` mirrors it
    /// here so a test can verify the balance directly.
    @MainActor
    func testListenerAddRemoveBalanceAcrossRebinds() {
        let reader = FakeVolumeReader()
        let observer = SystemVolumeObserver(reader: reader)

        // Init: +1 default-device listener + 2 device listeners (volume, mute) = 3 Adds.
        XCTAssertEqual(observer.addedListenerCountForTesting, 3)
        XCTAssertEqual(observer.removedListenerCountForTesting, 0)

        // A rebind must remove the two device listeners and re-add a fresh pair, so
        // adds increase by 2 and removes by 2 — net no leak.
        reader.device = AudioDeviceID(2)
        observer.rebindForTesting()
        XCTAssertEqual(observer.addedListenerCountForTesting, 5)
        XCTAssertEqual(observer.removedListenerCountForTesting, 2)

        // Rebind to "no default device": removes the current pair, adds none. Drift OK.
        reader.device = nil
        observer.rebindForTesting()
        XCTAssertEqual(observer.addedListenerCountForTesting, 5)
        XCTAssertEqual(observer.removedListenerCountForTesting, 4)

        // Final teardown removes the system-object default-device listener.
        observer.tearDownForTesting()
        XCTAssertEqual(
            observer.addedListenerCountForTesting,
            observer.removedListenerCountForTesting,
            "every Add must be paired with a Remove — no listener leak across the lifecycle"
        )
    }

    /// A teardown after a rebind that left a live device-pair removes the full set
    /// (default-device + the live device pair) cleanly.
    @MainActor
    func testTearDownRemovesAllOutstandingListeners() {
        let reader = FakeVolumeReader()
        let observer = SystemVolumeObserver(reader: reader)
        observer.tearDownForTesting()
        XCTAssertEqual(
            observer.addedListenerCountForTesting,
            observer.removedListenerCountForTesting
        )
    }
}
