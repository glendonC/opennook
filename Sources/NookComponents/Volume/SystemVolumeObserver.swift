// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Combine
import CoreAudio
import Foundation

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
public final class SystemVolumeObserver: ObservableObject {
    /// Current output volume, `0...1`. `0` when no output device is available.
    @Published public private(set) var volume: Double = 0

    /// Whether the default output device is muted.
    @Published public private(set) var isMuted: Bool = false

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private let queue = DispatchQueue.main

    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var muteListener: AudioObjectPropertyListenerBlock?

    public init() {
        observeDefaultDeviceChanges()
        rebindToDefaultDevice()
    }

    deinit {
        removeDeviceListeners()
        if let listener = defaultDeviceListener {
            var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, queue, listener
            )
        }
    }

    // MARK: - Device binding

    /// Re-points the observer at the current default output device, moving the volume
    /// and mute listeners onto it. Called on launch and whenever the default changes.
    private func rebindToDefaultDevice() {
        removeDeviceListeners()

        guard let device = Self.defaultOutputDevice() else {
            deviceID = AudioObjectID(kAudioObjectUnknown)
            return
        }
        deviceID = device

        let onChange: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.refresh()
        }

        var volumeAddress = Self.address(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput)
        AudioObjectAddPropertyListenerBlock(device, &volumeAddress, queue, onChange)
        volumeListener = onChange

        var muteAddress = Self.address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput)
        AudioObjectAddPropertyListenerBlock(device, &muteAddress, queue, onChange)
        muteListener = onChange

        refresh()
    }

    private func observeDefaultDeviceChanges() {
        let onChange: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.rebindToDefaultDevice()
        }
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, queue, onChange
        )
        defaultDeviceListener = onChange
    }

    private func removeDeviceListeners() {
        guard deviceID != AudioObjectID(kAudioObjectUnknown) else {
            volumeListener = nil
            muteListener = nil
            return
        }
        if let listener = volumeListener {
            var address = Self.address(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput)
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, queue, listener)
        }
        if let listener = muteListener {
            var address = Self.address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput)
            AudioObjectRemovePropertyListenerBlock(deviceID, &address, queue, listener)
        }
        volumeListener = nil
        muteListener = nil
    }

    /// Re-reads volume and mute from the bound device. Runs on the main queue (the
    /// listener blocks are dispatched there), so the `@Published` updates are main-thread.
    private func refresh() {
        guard deviceID != AudioObjectID(kAudioObjectUnknown) else { return }
        if let level = Self.readVolume(deviceID) {
            volume = min(max(level, 0), 1)
        }
        isMuted = Self.readMute(deviceID)
    }

    // MARK: - CoreAudio reads

    private static func address(
        _ selector: AudioObjectPropertySelector,
        _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var address = address(kAudioHardwarePropertyDefaultOutputDevice)
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        return status == noErr && device != AudioObjectID(kAudioObjectUnknown) ? device : nil
    }

    /// Reads the device's output volume — the main-element scalar if it has one,
    /// otherwise the average of the per-channel scalars. `nil` if neither is available.
    private static func readVolume(_ device: AudioDeviceID) -> Double? {
        var mainAddress = address(kAudioDevicePropertyVolumeScalar, kAudioObjectPropertyScopeOutput)
        if AudioObjectHasProperty(device, &mainAddress) {
            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &mainAddress, 0, nil, &size, &value) == noErr {
                return Double(value)
            }
        }

        var total = 0.0
        var count = 0.0
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
                total += Double(value)
                count += 1
            }
        }
        return count > 0 ? total / count : nil
    }

    private static func readMute(_ device: AudioDeviceID) -> Bool {
        var muteAddress = address(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput)
        guard AudioObjectHasProperty(device, &muteAddress) else { return false }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &value) == noErr else {
            return false
        }
        return value != 0
    }
}
