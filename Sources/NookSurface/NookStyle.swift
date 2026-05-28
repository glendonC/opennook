// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim — DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin — OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// Notch shape parameters and the spring/snap defaults the surface animates with.
///
/// Outer radius = inner radius + padding. Top is the small rounding into the notch arch,
/// bottom is the larger rounding where the panel meets the wallpaper.
public struct NookStyle: Equatable, Sendable {
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat

    public init(topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    /// Reasonable default that reads well next to the system menu bar on most notched MacBooks.
    public static let standard = NookStyle(topCornerRadius: 15, bottomCornerRadius: 20)

    /// The surface's built-in expand animation. Used when neither
    /// ``NookTransitionConfiguration/openingAnimation`` nor a host override is supplied.
    public var openingAnimation: Animation { .bouncy(duration: 0.4) }
    /// The surface's built-in collapse animation. See ``openingAnimation``.
    public var closingAnimation: Animation { .smooth(duration: 0.4) }
    /// The surface's built-in compact↔expanded animation. See ``openingAnimation``.
    public var conversionAnimation: Animation { .snappy(duration: 0.4) }
}
