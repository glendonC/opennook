// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import Foundation

/// Lifecycle of the nook surface. `NookKit` drives this through ``Nook/expand(on:)``,
/// ``Nook/compact(on:)``, and ``Nook/hide()``.
public enum NookState: Equatable, Sendable {
    case expanded
    case compact
    case hidden
}
