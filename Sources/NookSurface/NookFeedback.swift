// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import Foundation

/// A peripheral cue the chrome can play along its perimeter - a one-shot signal the user
/// catches at the edge of vision without having to look directly at the notch.
///
/// Trigger one with ``Nook/playFeedback(_:tint:duration:repeats:)``. Modeled as an enum so
/// new effects can be added without reshaping call sites.
public enum NookFeedback: String, CaseIterable, Codable, Sendable {
    /// A bright band sweeping the chrome's perimeter from the leading to the trailing edge.
    /// The most legible peripheral cue against the dark notch arch - a moving highlight that
    /// grazes the eye without reading as a notification badge.
    case shimmer

    /// No peripheral feedback.
    case none
}
