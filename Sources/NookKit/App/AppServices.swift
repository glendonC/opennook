// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation
import SwiftUI

/// A key into the per-module ``AppServices`` container.
///
/// This is the SwiftUI `EnvironmentKey` pattern applied to dependency injection: a
/// service is keyed by a *key type* it declares — not by its own runtime type — and the
/// key carries a `defaultValue` so resolution is total (never optional). A module
/// declares one key per service it offers:
///
/// ```swift
/// struct ClipboardServiceKey: ServiceKey {
///     static let defaultValue = ClipboardService()
/// }
/// ```
///
/// Keying by an explicit type (rather than the service's own type) means the registered
/// `Value` can be a protocol existential or a struct, and the same concrete type can
/// back two distinct keys.
public protocol ServiceKey {
    /// The type of value this key stores.
    associatedtype Value

    /// The value ``AppServices/resolve(_:)`` returns when nothing was registered for
    /// this key — the dependency-injection analogue of `EnvironmentKey.defaultValue`.
    static var defaultValue: Value { get }
}

/// A per-module, type-safe dependency container, threaded into a module's views via the
/// SwiftUI environment (`\.appServices`).
///
/// Each ``NookModule`` gets its own `AppServices` through its ``NookModuleContext``, so
/// two modules in the same host process never share or collide on services. A module
/// registers what it needs against a ``ServiceKey`` and its views resolve it back the
/// same way:
///
/// ```swift
/// // A module declares a key and registers an instance when it is constructed:
/// struct ClipboardServiceKey: ServiceKey {
///     static let defaultValue = ClipboardService()
/// }
/// context.services.register(ClipboardServiceKey.self, ClipboardService())
///
/// // ...a view resolves it — non-optional, falling back to the key's default:
/// @Environment(\.appServices) private var services
/// let clipboard = services.resolve(ClipboardServiceKey.self)
/// ```
///
/// Expected to be used from the main actor: registration happens when a module is
/// constructed, resolution happens during view rendering. It is intentionally not
/// `@MainActor` so SwiftUI's `EnvironmentKey.defaultValue` initializer stays callable
/// from any context.
public final class AppServices {
    private var storage: [ObjectIdentifier: Any] = [:]

    public init() {}

    /// Registers `value` for `key`.
    ///
    /// A key is meant to be registered exactly once, when the owning module is built;
    /// registering the same key twice is a programming error and traps in debug builds.
    /// In release builds the later registration wins.
    public func register<K: ServiceKey>(_ key: K.Type, _ value: K.Value) {
        let id = ObjectIdentifier(key)
        assert(
            storage[id] == nil,
            "AppServices: service key \(key) registered twice — register each key once."
        )
        storage[id] = value
    }

    /// Returns the value registered for `key`, or `key`'s `defaultValue` when nothing
    /// was registered. Resolution is total: it never returns `nil`.
    public func resolve<K: ServiceKey>(_ key: K.Type) -> K.Value {
        storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue
    }

    /// Subscript form of ``register(_:_:)`` / ``resolve(_:)``. Reading falls back to the
    /// key's `defaultValue`; writing stores the value (bypassing the double-register
    /// assertion, so a subscript `set` is the way to deliberately replace a value).
    public subscript<K: ServiceKey>(_ key: K.Type) -> K.Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}

private struct AppServicesEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppServices = AppServices()
}

public extension EnvironmentValues {
    var appServices: AppServices {
        get { self[AppServicesEnvironmentKey.self] }
        set { self[AppServicesEnvironmentKey.self] = newValue }
    }
}
