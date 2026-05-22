// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation
import os

/// Small capability probes the shelf consults at runtime.
///
/// Kept in its own type — and not on `ShelfStore` — so the App Sandbox check is
/// reachable from any shelf code (the drag-out delegate, future per-item probes)
/// without taking an actor hop into the store.
public enum ShelfRuntime {
    /// `true` when the host is running under the App Sandbox.
    ///
    /// Uses the `APP_SANDBOX_CONTAINER_ID` environment variable that the system sets
    /// on every sandboxed process — the canonical macOS signal. Cheap and safe to call
    /// from any thread; the result cannot change over a process's lifetime.
    public static let isSandboxed: Bool = {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }()

    /// The shelf's OS-level logger. Use for one-shot diagnostics that a host can grep
    /// for in `log show` — not for noisy per-event logging.
    static let log = Logger(subsystem: "dev.opennook.shelf", category: "ShelfStore")
}
