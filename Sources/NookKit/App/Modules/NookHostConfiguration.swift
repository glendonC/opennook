// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// The host-level registration seam: which modules a multi-module notch app offers,
/// and which one opens at launch.
///
/// Where ``NookConfiguration`` registers a *single* notch app's content,
/// `NookHostConfiguration` registers the *set* of interchangeable modules a host
/// process owns. Pass one to `NookApp.main(_:)`:
///
/// ```swift
/// var host = NookHostConfiguration()
/// host.register(NuggieModule.descriptor) { context in NuggieModule(context: context) }
/// host.register(ClipboardModule.descriptor) { context in ClipboardModule(context: context) }
/// host.defaultModule = NuggieModule.descriptor.id
/// NookApp.main(host)
/// ```
public struct NookHostConfiguration {
    private var entries: [NookModuleRegistry.Registration] = []
    private var explicitDefault: String?

    public init() {}

    /// Registers a module by descriptor and factory. The factory receives the module's
    /// isolated ``NookModuleContext`` and is run lazily — only when the module is first
    /// activated, not at registration time.
    public mutating func register(
        _ descriptor: NookModuleDescriptor,
        factory: @escaping @MainActor (NookModuleContext) -> NookModule
    ) {
        entries.append(NookModuleRegistry.Registration(descriptor: descriptor, factory: factory))
    }

    /// Registers a module that is just a ``NookConfiguration`` with no extra product
    /// state — the configuration is wrapped in a ``ClosureModule``.
    public mutating func register(
        _ descriptor: NookModuleDescriptor,
        configuration: @escaping @MainActor () -> NookConfiguration
    ) {
        register(descriptor) { _ in
            ClosureModule(descriptor: descriptor, build: configuration)
        }
    }

    /// The id of the module to show at launch. When `nil`, the first registered module
    /// is used.
    public var defaultModule: String? {
        get { explicitDefault }
        set { explicitDefault = newValue }
    }

    /// `true` until at least one module is registered.
    public var isEmpty: Bool { entries.isEmpty }

    /// Builds the live registry. The default module is the explicit choice when set and
    /// still registered, otherwise the first registered module.
    @MainActor
    public func makeRegistry() -> NookModuleRegistry {
        let registeredIDs = Set(entries.map { $0.descriptor.id })
        let defaultID = explicitDefault.flatMap { registeredIDs.contains($0) ? $0 : nil }
            ?? entries.first?.descriptor.id
            ?? ""
        return NookModuleRegistry(registrations: entries, defaultModuleID: defaultID)
    }
}
