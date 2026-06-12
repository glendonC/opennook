// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import Foundation
import SwiftUI

/// One-shot peripheral feedback request. Held by ``Nook`` and consumed by ``NookFeedbackOverlay``.
///
/// `id` is a fresh UUID per event so the view's `.onChange` / equality plumbing can detect
/// rapid successive triggers and restart the animation rather than fall through as a no-op.
struct NookFeedbackEvent: Equatable {
    let id: UUID
    let startedAt: Date
    let effect: NookFeedback
    let duration: TimeInterval
    let tint: Color
    let respectsReduceMotion: Bool
    /// When `true`, the overlay loops the animation indefinitely instead of fading to clear after
    /// one cycle. The host clears the event (e.g., when the nook expands) to stop the loop.
    let repeats: Bool
}
