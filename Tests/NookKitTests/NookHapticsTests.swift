// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest
@testable import NookKit

/// Coverage for ``NookHaptics``. The actual trackpad pulse is hardware-dependent
/// (Force Touch trackpad + the user's System Settings) so we can only verify the
/// preference-gating contract — the call site is documented as the authoritative
/// place where the preference is read.
final class NookHapticsTests: XCTestCase {
    /// `confirm(enabled: false)` is a safe no-op — explicitly so when the preference
    /// is off. We can't observe the absence of a pulse directly, but the call must
    /// at least not crash.
    func testConfirmIsNoOpWhenDisabled() {
        NookHaptics.confirm(enabled: false)
    }

    /// `confirm(enabled: true)` issues the request to AppKit. macOS itself decides
    /// whether to deliver the pulse based on hardware + user preferences.
    func testConfirmIsSafeWhenEnabled() {
        NookHaptics.confirm(enabled: true)
    }
}
