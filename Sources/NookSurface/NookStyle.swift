// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// Per-edge insets, expressed in the leading/trailing reading direction (matching
/// SwiftUI's `EdgeInsets`). Used by ``NookStyle/expandedContentInsets`` to describe
/// the safe-area strip the chrome reserves around the host's expanded content.
public struct NookEdgeInsets: Equatable, Sendable {
    public var top: CGFloat
    public var bottom: CGFloat
    public var leading: CGFloat
    public var trailing: CGFloat

    public init(top: CGFloat = 0, bottom: CGFloat = 0, leading: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.bottom = bottom
        self.leading = leading
        self.trailing = trailing
    }

    /// Same inset on all four edges.
    public init(_ all: CGFloat) {
        self.init(top: all, bottom: all, leading: all, trailing: all)
    }

    public static let zero = NookEdgeInsets()
}

/// Notch shape parameters and the spring/snap defaults the surface animates with.
///
/// Outer radius = inner radius + padding. Top is the small rounding into the notch arch,
/// bottom is the larger rounding where the panel meets the wallpaper.
public struct NookStyle: Equatable, Sendable {
    public var topCornerRadius: CGFloat
    public var bottomCornerRadius: CGFloat

    /// Safe-area strip the chrome reserves around the host's expanded content, applied
    /// as `.safeAreaInset` on each edge of the expanded surface. This is the chrome's
    /// own clearance - distinct from any padding a host wrapper (e.g. `NookExpandedView`)
    /// adds inside it.
    ///
    /// The default (``standardExpandedContentInsets``) reproduces the historical fixed
    /// geometry: 0 on top (the top corner curve is meant to land inside the host frame,
    /// so the published ``NookContentInsets/top`` reports the full `topCornerRadius`) and
    /// 8 on the other three edges.
    ///
    /// Tightening `bottom` lets content sit closer to the rounded bottom - useful when a
    /// host wants to reclaim the dead band below its last row. Because the bottom corners
    /// curve inward by `bottomCornerRadius`, content pinned into a *bottom corner* will
    /// intersect that curve once `bottom` drops below it; the published
    /// ``EnvironmentValues/nookContentInsets`` reports the residual a host must apply to
    /// clear it. Centered content (e.g. a command row) stays horizontally clear of the
    /// corners and is unaffected, so it can safely sit at the reduced bottom inset.
    public var expandedContentInsets: NookEdgeInsets

    public init(
        topCornerRadius: CGFloat,
        bottomCornerRadius: CGFloat,
        expandedContentInsets: NookEdgeInsets = NookStyle.standardExpandedContentInsets
    ) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
        self.expandedContentInsets = expandedContentInsets
    }

    /// The historical expanded-content safe-area strip: no top inset (the top corner
    /// curve lands inside the host frame), 8 pt on the other three edges.
    public static let standardExpandedContentInsets = NookEdgeInsets(
        top: 0,
        bottom: 8,
        leading: 8,
        trailing: 8
    )

    /// Reasonable default that reads well next to the system menu bar on most notched MacBooks.
    public static let standard = NookStyle(topCornerRadius: 15, bottomCornerRadius: 20)

    /// The surface's built-in expand animation. Used when neither
    /// ``NookTransitionConfiguration/openingAnimation`` nor a host override is supplied.
    public var openingAnimation: Animation { .bouncy(duration: 0.4) }
    /// The surface's built-in collapse animation. See ``openingAnimation``.
    public var closingAnimation: Animation { .smooth(duration: 0.4) }
    /// The surface's built-in compact<->expanded animation. See ``openingAnimation``.
    public var conversionAnimation: Animation { .snappy(duration: 0.4) }
}
