// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// The set of modules a host registered, plus lazy construction and caching of their
/// live instances.
///
/// Registration is cheap (descriptors + factories); construction is deferred until a
/// module is first activated. A constructed module is cached with its
/// ``NookModuleContext`` until ``unload(_:)`` drops it — which the host does for a
/// module whose ``NookModuleDescriptor/backgroundPolicy`` is `.unloadOnSwitchAway`.
@MainActor
public final class NookModuleRegistry {
    struct Registration {
        let descriptor: NookModuleDescriptor
        let factory: @MainActor (NookModuleContext) -> NookModule
    }

    private let registrations: [Registration]

    /// The module shown at launch — the host's explicit choice, else the first registered.
    public let defaultModuleID: String

    private var instances: [String: NookModule] = [:]
    private var contexts: [String: NookModuleContext] = [:]

    init(registrations: [Registration], defaultModuleID: String) {
        self.registrations = registrations
        self.defaultModuleID = defaultModuleID
    }

    /// All registered modules' descriptors, in registration order — the switcher's list.
    public var descriptors: [NookModuleDescriptor] {
        registrations.map(\.descriptor)
    }

    public func descriptor(for id: String) -> NookModuleDescriptor? {
        registrations.first { $0.descriptor.id == id }?.descriptor
    }

    /// Lazily constructs (and caches) the module for `id`, building its isolated
    /// ``NookModuleContext`` on first access. `nil` for an unregistered id.
    @discardableResult
    public func module(for id: String) -> NookModule? {
        if let existing = instances[id] { return existing }
        guard let registration = registrations.first(where: { $0.descriptor.id == id }) else {
            return nil
        }
        let context = NookModuleContext.makeDefault(for: registration.descriptor)
        let module = registration.factory(context)
        contexts[id] = context
        instances[id] = module
        return module
    }

    /// The isolated context for `id`, constructing the module if needed.
    public func context(for id: String) -> NookModuleContext? {
        module(for: id)
        return contexts[id]
    }

    /// `true` once the module for `id` has been constructed and not since unloaded.
    public func isLoaded(_ id: String) -> Bool {
        instances[id] != nil
    }

    /// Drops the cached instance and context for `id`. The next ``module(for:)`` rebuilds
    /// it from scratch with a fresh context. Used to honor
    /// `BackgroundPolicy.unloadOnSwitchAway`.
    public func unload(_ id: String) {
        instances.removeValue(forKey: id)
        contexts.removeValue(forKey: id)
    }
}
