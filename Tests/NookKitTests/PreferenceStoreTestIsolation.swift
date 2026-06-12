// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// Serializes access to the process-global `opennook.*` preference keys while tests run
/// with `swift test --parallel`. Without this, one test's persisted values leak into
/// another test's launch-seed assertions.
enum PreferenceStoreTestIsolation {
    static let storeKeys = [
        "opennook.appearance.v1",
        "opennook.hotkey.v1",
        "opennook.display.v1",
    ]

    private static let lock = NSLock()

    static func withIsolatedStore<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }

        var saved: [String: Data] = [:]
        for key in storeKeys {
            saved[key] = UserDefaults.standard.data(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
        defer {
            for key in storeKeys {
                if let data = saved[key] {
                    UserDefaults.standard.set(data, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }

        return try body()
    }

    static func withIsolatedStore<T>(_ body: () async throws -> T) async rethrows -> T {
        lock.lock()
        defer { lock.unlock() }

        var saved: [String: Data] = [:]
        for key in storeKeys {
            saved[key] = UserDefaults.standard.data(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
        defer {
            for key in storeKeys {
                if let data = saved[key] {
                    UserDefaults.standard.set(data, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }

        return try await body()
    }
}
