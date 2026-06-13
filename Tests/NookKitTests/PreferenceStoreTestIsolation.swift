// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

@testable import NookKit

/// Points the preference stores at a fresh, isolated `UserDefaults` suite for the
/// duration of `body`, then tears it down. Each call gets a unique suite (by UUID).
///
/// `swift test --parallel` runs each test class in its own process against the one
/// shared global `UserDefaults` domain, so one test's persisted values otherwise leak
/// into another's launch-seed assertions. An in-process lock cannot serialize across
/// those processes; isolating by private domain does, because every process and every
/// call writes to a domain no other reader sees.
///
/// The sync and async `withIsolatedStore` overloads are intentional (callers pick by
/// whether their body is async); the trailing-closure ambiguity rule is a false positive.
// swift-format-ignore: AmbiguousTrailingClosureOverload
enum PreferenceStoreTestIsolation {
    /// The keys the stores persist, so tests can assert nothing was written.
    static let storeKeys = [
        "opennook.appearance.v1",
        "opennook.hotkey.v1",
        "opennook.display.v1",
    ]

    static func withIsolatedStore<T>(_ body: () throws -> T) rethrows -> T {
        let (name, defaults) = makeSuite()
        let previous = NookPreferenceStorage.defaults
        NookPreferenceStorage.defaults = defaults
        defer {
            NookPreferenceStorage.defaults = previous
            defaults.removePersistentDomain(forName: name)
        }
        return try body()
    }

    static func withIsolatedStore<T>(_ body: () async throws -> T) async rethrows -> T {
        let (name, defaults) = makeSuite()
        let previous = NookPreferenceStorage.defaults
        NookPreferenceStorage.defaults = defaults
        defer {
            NookPreferenceStorage.defaults = previous
            defaults.removePersistentDomain(forName: name)
        }
        return try await body()
    }

    /// A brand-new, empty `UserDefaults` suite. The UUID name makes a collision with any
    /// other process or prior run effectively impossible; the clear is belt-and-suspenders.
    private static func makeSuite() -> (name: String, defaults: UserDefaults) {
        let name = "opennook.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            fatalError("Could not create isolated UserDefaults suite '\(name)'")
        }
        defaults.removePersistentDomain(forName: name)
        return (name, defaults)
    }
}
