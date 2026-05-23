// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Combine
import CoreAudio
import Foundation

/// The device/volume/mute reads ``SystemVolumeObserver`` depends on.
///
/// Factored behind a protocol so the observer's CoreAudio dependency is an injectable
/// seam — production uses ``CoreAudioVolumeReader``; tests pass a fake so the
/// default-device rebind, the main-element-vs-per-channel fallback, mute reads, and
/// clamping can all be exercised without a live audio device. This mirrors the
/// injectable `sleep` closure on `NookActivityQueue`.
///
/// `Sendable` because a reader is captured into CoreAudio listener blocks, which run on
/// an arbitrary queue before hopping to the main actor.
public protocol VolumeReading: Sendable {
    /// The current default output device, or `nil` when none is available.
    func defaultOutputDevice() -> AudioDeviceID?

    /// The device's output volume — `nil` when neither a main-element scalar nor any
    /// per-channel scalar can be read. Not required to be clamped; the observer clamps.
    func readVolume(_ device: AudioDeviceID) -> Double?

    /// Whether the device is muted. `false` when the device exposes no mute property.
    func readMute(_ device: AudioDeviceID) -> Bool
}

/// Observes the system's default-output-device volume and mute state.
///
/// Built entirely on public CoreAudio property listeners — no private API, no special
/// entitlement, App Store-safe. It tracks the *default output device* and re-binds when
/// that changes (headphones plugged in, an output switched in Control Center), so the
/// reported level always follows wherever sound is going.
///
/// This is an *ambient* indicator, not an HUD: render ``volume``/``isMuted`` as a
/// persistent compact-slot glyph (see ``NookVolumeIndicator``). It does not intercept or
/// replace Apple's volume overlay.
///
/// `@MainActor`-isolated: the `@Published` properties drive SwiftUI, and CoreAudio
/// listener callbacks (which arrive on an arbitrary queue) hop to the main actor before
/// touching any state. This matches the concurrency contract of `NookActivityQueue`.
@MainActor
public final class SystemVolumeObserver: ObservableObject {
    /// Current output volume, `0...1`. `0` when no output device is available.
    @Published public private(set) var volume: Double = 0

    /// Whether the default output device is muted.
    @Published public private(set) var isMuted: Bool = false

    private var deviceID = AudioObjectID(kAudioObjectUnknown)

    /// The injectable read seam — real CoreAudio in production, a fake in tests.
    private let reader: VolumeReading

    /// CoreAudio listener block type. `AudioObjectPropertyListenerBlock` is imported
    /// without a `@Sendable` annotation, but a listener block is genuinely sendable: it
    /// is invoked on an arbitrary CoreAudio queue and the blocks here only capture a
    /// `[weak self]` to a `@MainActor`-isolated (hence `Sendable`) observer, hopping to
    /// the main actor before touching any state. Spelling the type `@Sendable` lets the
    /// non-isolated `deinit` read these to unregister them without a strict-concurrency
    /// violation.
    private typealias ListenerBlock =
        @Sendable (UInt32, UnsafePointer<AudioObjectPropertyAddress>) -> Void

    private var defaultDeviceListener: ListenerBlock?
    private var volumeListener: ListenerBlock?
    private var muteListener: ListenerBlock?

    /// Internal counters: number of `AudioObjectAddPropertyListenerBlock` and
    /// `AudioObjectRemovePropertyListenerBlock` calls the observer has made over its
    /// lifetime. Used by the test suite to verify add/remove balance — every Add must
    /// be paired with a Remove. Atomic-int-safe because the observer is `@MainActor`
    /// and all mutations are on the main actor.
    var addedListenerCountForTesting: Int = 0
    var removedListenerCountForTesting: Int = 0

    /// - Parameter reader: how the observer queries the device, volume, and mute state.
    ///   Defaults to the real CoreAudio implementation; tests inject a fake.
    public init(reader: VolumeReading = CoreAudioVolumeReader()) {
        self.reader = reader
        // `init` runs on the main actor (the type is `@MainActor`-isolated), so the
        // binding below — which writes `@Published` state — is already correct. The
        // CoreAudio listener blocks registered here are dispatched on the main queue and
        // hop back to the main actor before mutating anything; no `Thread.isMainThread`
        // guard is needed now that the isolation is real and enforced by the compiler.
        observeDefaultDeviceChanges()
        rebindToDefaultDevice()
    }

    deinit {
        // `deinit` is non-isolated and may run on any thread. It is sound regardless:
        // `AudioObjectRemovePropertyListenerBlock` is itself thread-safe, and the
        // listener/device state read here is only ever written on the main actor — once
        // the last reference is gone no listener block can still be racing this. The
        // listener removal is inlined here (rather than calling the main-actor
        // `removeDeviceListeners()`) precisely because `deinit` is non-isolated.
        if deviceID != AudioObjectID(kAudioObjectUnknown) {
            if let listener = volumeListener {
                var address = Self.address(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput)
                AudioObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, listener)
            }
            if let listener = muteListener {
                var address = Self.address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput)
                AudioObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, listener)
            }
        }
        if let listener = defaultDeviceListener {
            var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener
            )
        }
    }

    // MARK: - Device binding

    /// Test-only seam: drives a default-device rebind without a CoreAudio listener
    /// callback, so the rebind/re-read path can be unit-tested with a fake reader.
    /// Production code rebinds only via the listener block in ``observeDefaultDeviceChanges()``.
    func rebindForTesting() {
        rebindToDefaultDevice()
    }

    /// Test-only seam: runs the same listener teardown `deinit` does, but on the
    /// main actor so it can bump the test counters. Idempotent — calling it twice
    /// will only decrement once for any listener it actually removed.
    func tearDownForTesting() {
        removeDeviceListeners()
        if let listener = defaultDeviceListener {
            var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, listener
            )
            defaultDeviceListener = nil
            removedListenerCountForTesting += 1
        }
    }

    /// Re-points the observer at the current default output device, moving the volume
    /// and mute listeners onto it. Called on launch and whenever the default changes.
    private func rebindToDefaultDevice() {
        removeDeviceListeners()

        guard let device = reader.defaultOutputDevice() else {
            deviceID = AudioObjectID(kAudioObjectUnknown)
            volume = 0
            isMuted = false
            return
        }
        deviceID = device

        let onChange: ListenerBlock = { [weak self] _, _ in
            // Listener blocks are dispatched on the main *queue*, which is not the main
            // *actor*; hop explicitly before touching `@Published` state.
            Task { @MainActor in self?.refresh() }
        }

        var volumeAddress = Self.address(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput)
        AudioObjectAddPropertyListenerBlock(device, &volumeAddress, DispatchQueue.main, onChange)
        volumeListener = onChange
        addedListenerCountForTesting += 1

        var muteAddress = Self.address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput)
        AudioObjectAddPropertyListenerBlock(device, &muteAddress, DispatchQueue.main, onChange)
        muteListener = onChange
        addedListenerCountForTesting += 1

        refresh()
    }

    private func observeDefaultDeviceChanges() {
        let onChange: ListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.rebindToDefaultDevice() }
        }
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, DispatchQueue.main, onChange
        )
        defaultDeviceListener = onChange
        addedListenerCountForTesting += 1
    }

    private func removeDeviceListeners() {
        guard deviceID != AudioObjectID(kAudioObjectUnknown) else {
            volumeListener = nil
            muteListener = nil
            return
        }
        if let listener = volumeListener {
            var address = Self.address(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput)
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, listener)
            removedListenerCountForTesting += 1
        }
        if let listener = muteListener {
            var address = Self.address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput)
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, DispatchQueue.main, listener)
            removedListenerCountForTesting += 1
        }
        volumeListener = nil
        muteListener = nil
    }

    /// Re-reads volume and mute from the bound device through the injected reader.
    /// Runs on the main actor, so the `@Published` updates are main-thread.
    private func refresh() {
        guard deviceID != AudioObjectID(kAudioObjectUnknown) else { return }
        if let level = reader.readVolume(deviceID) {
            volume = min(max(level, 0), 1)
        }
        isMuted = reader.readMute(deviceID)
    }

    // MARK: - Property addresses

    /// `nonisolated` so the non-isolated `deinit` and the `Sendable`
    /// ``CoreAudioVolumeReader`` can both build addresses — the function is pure.
    nonisolated static func address(
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}

/// The main-element-vs-per-channel-average volume fallback, as a pure function so the
/// decision is unit-testable without a live device.
///
/// CoreAudio devices expose volume either as a single main-element scalar or only as
/// per-channel scalars. This picks the main scalar when present, otherwise averages
/// whatever per-channel scalars resolved, and returns `nil` when neither is available.
///
/// - Parameters:
///   - mainScalar: the main-element volume, or `nil` if the device has no main scalar.
///   - channelScalars: the per-channel volumes that resolved (may be empty).
func resolveVolumeFallback(mainScalar: Double?, channelScalars: [Double]) -> Double? {
    if let mainScalar { return mainScalar }
    guard !channelScalars.isEmpty else { return nil }
    return channelScalars.reduce(0, +) / Double(channelScalars.count)
}

/// The production ``VolumeReading`` — talks to CoreAudio directly. Stateless and
/// `Sendable`, so it is safe to capture into the observer's listener blocks.
public struct CoreAudioVolumeReader: VolumeReading {
    public init() {}

    public func defaultOutputDevice() -> AudioDeviceID? {
        var address = SystemVolumeObserver.address(kAudioHardwarePropertyDefaultOutputDevice)
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        return status == noErr && device != AudioObjectID(kAudioObjectUnknown) ? device : nil
    }

    /// Reads the device's output volume — the main-element scalar if it has one,
    /// otherwise the average of the per-channel scalars. The main-vs-channel decision is
    /// delegated to ``resolveVolumeFallback(mainScalar:channelScalars:)``.
    public func readVolume(_ device: AudioDeviceID) -> Double? {
        var mainScalar: Double?
        var mainAddress = SystemVolumeObserver.address(
            kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput
        )
        if AudioObjectHasProperty(device, &mainAddress) {
            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &mainAddress, 0, nil, &size, &value) == noErr {
                mainScalar = Double(value)
            }
        }

        var channelScalars: [Double] = []
        for channel in [UInt32(1), UInt32(2)] {
            var channelAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: channel
            )
            guard AudioObjectHasProperty(device, &channelAddress) else { continue }
            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &channelAddress, 0, nil, &size, &value) == noErr {
                channelScalars.append(Double(value))
            }
        }
        return resolveVolumeFallback(mainScalar: mainScalar, channelScalars: channelScalars)
    }

    public func readMute(_ device: AudioDeviceID) -> Bool {
        var muteAddress = SystemVolumeObserver.address(
            kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput
        )
        guard AudioObjectHasProperty(device, &muteAddress) else { return false }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &value) == noErr else {
            return false
        }
        return value != 0
    }
}
