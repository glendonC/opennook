// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// The `UserDefaults` the preference stores (``NookAppearanceStore``, ``NookHotkeyStore``,
/// ``NookDisplayStore``) read and write through.
///
/// Defaults to `.standard` and production never reassigns it, so library behavior is
/// unchanged. The test suite repoints it at an isolated, per-test suite: `swift test
/// --parallel` runs each test class in its own process against the one shared global
/// domain, so without a private domain one test's persisted values leak into another's
/// launch-seed assertions - and an in-process lock cannot serialize across processes.
///
/// `nonisolated(unsafe)`: the only writer is the (serial) test setup within each process;
/// production reads run on the main actor. Mirrors ``NookFilePicker``'s default-value seam.
enum NookPreferenceStorage {
    nonisolated(unsafe) static var defaults: UserDefaults = .standard
}
