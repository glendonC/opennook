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
/// `Sendable`: the registry entries hold only `Sendable` data (descriptors and
/// `@Sendable` factory closures). A host configuration is assembled at the nonisolated
/// top level of a `main.swift` and then handed to `NookApp.main`, which runs setup on
/// the main actor — a real isolation crossing, so the conformance must be genuine.
public struct NookHostConfiguration: Sendable {
    private var entries: [NookModuleRegistry.Registration] = []
    private var explicitDefault: String?

    /// Optional global shortcut that cycles to the next registered module. `nil` — the
    /// default — means cycling is reachable only through the switcher.
    public var moduleCycleHotkey: NookHotkey?

    public init() {}

    /// Registers a module by descriptor and factory. The factory receives the module's
    /// isolated ``NookModuleContext`` and is run lazily — only when the module is first
    /// activated, not at registration time.
    ///
    /// Traps on a duplicate `descriptor.id`. A module id keys persistence (the
    /// `UserDefaults` suite `"opennook.module.<id>"` and the per-module container
    /// folder), the switcher entry, the arbiter's per-module claim invalidation, and
    /// the direct-jump hotkey registration. Two registrations under the same id would
    /// collide on every one of those silently — the second factory becomes dead code,
    /// the persistence suites alias, and the switcher renders two indistinguishable
    /// entries — so we fail fast at the setup site (a `main.swift` programming bug)
    /// rather than ship the corruption into production.
    public mutating func register(
        _ descriptor: NookModuleDescriptor,
        factory: @escaping @Sendable @MainActor (NookModuleContext) -> NookModule
    ) {
        precondition(
            !entries.contains(where: { $0.descriptor.id == descriptor.id }),
            "NookHostConfiguration: duplicate module id '\(descriptor.id)'. " +
                "Module ids must be unique within a host — they key persistence, the " +
                "switcher entry, the per-module hotkey, and the arbiter's claim " +
                "invalidation."
        )
        entries.append(NookModuleRegistry.Registration(descriptor: descriptor, factory: factory))
    }

    /// Registers a module that is just a ``NookConfiguration`` with no extra product
    /// state — the configuration is wrapped in a ``ClosureModule``.
    ///
    /// Inherits the duplicate-id `precondition` from the factory overload it delegates
    /// to.
    public mutating func register(
        _ descriptor: NookModuleDescriptor,
        configuration: @escaping @Sendable @MainActor () -> NookConfiguration
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
    ///
    /// Traps on an empty configuration: `NookHostConfiguration` is the multi-module
    /// entry point and is meaningless with zero registrations. An empty registry's
    /// `activeModuleID` resolves to `""`, which the arbiter treats as "background
    /// module" for every claim — denying everything that isn't `.urgent`. That is a
    /// silent bug; failing fast at registration time surfaces it. Single-module hosts
    /// should use ``NookConfiguration`` directly, not `NookHostConfiguration`.
    @MainActor
    public func makeRegistry() -> NookModuleRegistry {
        precondition(
            !entries.isEmpty,
            "NookHostConfiguration: register at least one module before makeRegistry(). " +
                "For single-module apps, use NookConfiguration with NookApp.main(_:) instead."
        )
        let registeredIDs = Set(entries.map { $0.descriptor.id })
        let defaultID = explicitDefault.flatMap { registeredIDs.contains($0) ? $0 : nil }
            ?? entries.first!.descriptor.id
        return NookModuleRegistry(
            registrations: entries,
            defaultModuleID: defaultID,
            cycleHotkey: moduleCycleHotkey
        )
    }
}
