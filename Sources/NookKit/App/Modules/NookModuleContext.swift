// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// The isolated environment handed to a ``NookModule`` at construction.
///
/// Every module that coexists in one host process gets its own context, so two
/// modules never collide on persistence: distinct `UserDefaults` suites, distinct
/// on-disk container folders, distinct ``AppServices`` bags. A module that needs to
/// persist anything should route it through `context.defaults` / `context.containerURL`
/// rather than `UserDefaults.standard` or a hardcoded path.
@MainActor
public final class NookModuleContext {
    /// The module's registration-time identity.
    public let descriptor: NookModuleDescriptor

    /// Per-module `UserDefaults` suite (`"opennook.module.<id>"`). Component stores —
    /// e.g. `NookComponents`' `ShelfStore`, which already accepts an injected
    /// `defaults:` — should be wired to this so their keys can't collide across modules.
    public let defaults: UserDefaults

    /// Per-module service bag, injected into the module's views via `\.appServices`.
    public let services: AppServices

    /// Suggested on-disk container for module-owned files (databases, caches):
    /// `Application Support/<host>/Modules/<id>/`. Not created on disk — the module
    /// creates it on first use.
    public let containerURL: URL

    public init(
        descriptor: NookModuleDescriptor,
        defaults: UserDefaults,
        services: AppServices,
        containerURL: URL
    ) {
        self.descriptor = descriptor
        self.defaults = defaults
        self.services = services
        self.containerURL = containerURL
    }

    /// Builds the default isolated context for a module id: a `"opennook.module.<id>"`
    /// suite and an `Application Support/<host>/Modules/<id>/` container.
    static func makeDefault(for descriptor: NookModuleDescriptor) -> NookModuleContext {
        let suiteName = "opennook.module.\(descriptor.id)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard

        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let host = Bundle.main.bundleIdentifier ?? "OpenNook"
        let containerURL = appSupport
            .appendingPathComponent(host, isDirectory: true)
            .appendingPathComponent("Modules", isDirectory: true)
            .appendingPathComponent(descriptor.id, isDirectory: true)

        return NookModuleContext(
            descriptor: descriptor,
            defaults: defaults,
            services: AppServices(),
            containerURL: containerURL
        )
    }
}
