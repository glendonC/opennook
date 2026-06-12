// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import AppKit

/// Async surface for driving any nook-shaped presenter (today: ``Nook``).
///
/// `expand`/`compact` take an optional target screen. Passing `nil` lets the
/// presenter resolve the screen itself - see ``Nook/screenProvider`` - which is
/// how multi-display host apps express a persisted display preference without
/// threading an `NSScreen` through every call site.
@MainActor
public protocol NookControllable {
    func expand(on screen: NSScreen?) async
    func compact(on screen: NSScreen?) async
    func hide() async
}
