// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

/// String ids the framework reserves for its own ``HotkeyController`` registrations.
///
/// Hoisted to a single source of truth so view code (Settings panels, the menu-bar
/// fallback) can match against them without a magic-string literal that drifts from
/// the registration call site in ``AppCoordinator``.
///
/// Module-defined registrations use `"module.\(id)"` and `"cycle"` — these too are
/// declared here so a host can recognise them when iterating
/// ``AppState/hotkeyRegistrationFailures``.
enum NookHotkeyIDs {
    /// The user-rebindable show/hide global shortcut. The one entry whose key is
    /// chosen by the user; the rest are static per launch.
    static let toggle = "toggle"

    /// The module-cycle global shortcut, when the host configured one.
    static let cycle = "cycle"

    /// String id under which a module-specific direct-jump shortcut is registered.
    static func module(_ id: String) -> String { "module.\(id)" }
}
