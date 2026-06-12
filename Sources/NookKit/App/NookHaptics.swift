// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit

/// Centralized trackpad haptics for completion-style events. Reads
/// `appearancePreferences.hapticFeedbackEnabled` at the call site - never fires when
/// the preference is off. macOS only delivers the pulse when the user's hand is on a
/// Force Touch trackpad and "Force Click and haptic feedback" is enabled in System
/// Settings, so a missed pulse on a mouse-driven session is expected, not a bug.
public enum NookHaptics {
    /// One-shot confirmation pulse for a completed action. `levelChange` is the AppKit
    /// pattern that reads as "thing happened, you're done."
    public static func confirm(enabled: Bool) {
        guard enabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .now
        )
    }
}
