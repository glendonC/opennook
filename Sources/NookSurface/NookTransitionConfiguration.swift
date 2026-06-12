// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// Per-instance overrides for the surface's animation curves. Nil values fall back to ``NookStyle`` defaults.
public struct NookTransitionConfiguration: Sendable {
    /// Hidden -> expanded / hidden -> compact.
    public var openingAnimation: Animation?
    /// Expanded -> hidden / compact -> hidden.
    public var closingAnimation: Animation?
    /// Compact <-> expanded.
    public var conversionAnimation: Animation?
    /// When `true`, compact<->expanded skips the intermediate hide-and-show.
    public var skipIntermediateHides: Bool

    /// Longest duration, in seconds, of any animation supplied above.
    ///
    /// SwiftUI's `Animation` exposes no portable duration accessor, so the surface cannot
    /// introspect a custom animation to know when it has visibly finished. An awaited
    /// `expand()`/`compact()` documents that it "returns once the chrome has visibly
    /// arrived"; to honor that contract for a *non-default* (typically slower) animation,
    /// a host that overrides the curves should set this to the longest of their
    /// durations. The surface sizes its post-animation settle delay from this value.
    ///
    /// `nil` (the default) means "the animations use the built-in ~0.4 s curves," and
    /// the surface falls back to its default settle constants. Set this only when you
    /// pass a custom animation whose duration differs materially from the default.
    public var animationDuration: TimeInterval?

    /// Short-lived grace after expanded content resizes. While active, hover-exit
    /// auto-compact is suppressed so a stationary cursor does not dismiss the nook
    /// when the chrome shape shrinks underneath it. `nil` uses the built-in default
    /// (~600 ms).
    public var layoutGraceDuration: TimeInterval?

    public init(
        openingAnimation: Animation? = nil,
        closingAnimation: Animation? = nil,
        conversionAnimation: Animation? = nil,
        skipIntermediateHides: Bool = false,
        animationDuration: TimeInterval? = nil,
        layoutGraceDuration: TimeInterval? = nil
    ) {
        self.openingAnimation = openingAnimation
        self.closingAnimation = closingAnimation
        self.conversionAnimation = conversionAnimation
        self.skipIntermediateHides = skipIntermediateHides
        self.animationDuration = animationDuration
        self.layoutGraceDuration = layoutGraceDuration
    }
}
