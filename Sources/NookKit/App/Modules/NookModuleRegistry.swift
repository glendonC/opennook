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
    /// A registered module: its descriptor plus a lazy factory.
    ///
    /// `Sendable` so a ``NookHostConfiguration`` built at the (nonisolated) top level of
    /// a `main.swift` can be handed to the main actor. The `factory` is `@Sendable`
    /// because that crossing genuinely happens; it stays `@MainActor` because module
    /// construction touches main-actor state.
    struct Registration: Sendable {
        let descriptor: NookModuleDescriptor
        let factory: @Sendable @MainActor (NookModuleContext) -> NookModule
    }

    private let registrations: [Registration]

    /// The module shown at launch — the host's explicit choice, else the first registered.
    public let defaultModuleID: String

    /// Optional global shortcut that cycles to the next module. `nil` when the host did
    /// not configure one.
    public let cycleHotkey: NookHotkey?

    /// Host-level product identity surfaced through the framework chrome (About card,
    /// show/hide hotkey label, menu-bar fallback). The registry holds it so
    /// ``ModuleHost`` can republish it without holding a reference back to the host
    /// configuration value.
    public let branding: NookHostBranding

    /// Process-global chrome behavior (hover side-effects, cold-launch shimmer,
    /// appearance→backdrop mapping). Held here for the same reason as ``branding`` — so
    /// ``ModuleHost`` and ``AppCoordinator`` can read it without a reference back to the
    /// host configuration. See ``NookChromeBehavior``.
    public let chromeBehavior: NookChromeBehavior

    /// Whether the framework installs its menu-bar status item. Held here so the app
    /// shell can read it (and observe it) through ``ModuleHost``.
    public let showsMenuBarExtra: Bool

    /// Where the module switcher appears (menu bar, leading cluster, or nowhere). Held
    /// here so the router and the app shell can read it through ``ModuleHost``. See
    /// ``NookModuleSwitcherPlacement``.
    public let switcherPlacement: NookModuleSwitcherPlacement

    /// One broker per host process, shared across every module. Registered into each
    /// module's ``AppServices`` as ``NookModuleContext`` is built, so a view in module A
    /// and a view in module B both resolve the same instance — pins compose into one
    /// aggregate signal the coordinator can fold into ``AppCoordinator/isUserEngaged``.
    public let presentationPinning: NookPresentationPinning

    /// One file picker per host process, shared across every module — same lifetime and
    /// rationale as ``presentationPinning`` (it depends on that broker to hold the
    /// surface while a panel is up). Registered into each module's ``AppServices`` as
    /// ``NookModuleContext`` is built. See ``NookFilePicker``.
    public let filePicker: NookFilePicker

    private var instances: [String: NookModule] = [:]
    private var contexts: [String: NookModuleContext] = [:]

    init(
        registrations: [Registration],
        defaultModuleID: String,
        cycleHotkey: NookHotkey?,
        branding: NookHostBranding = .default,
        chromeBehavior: NookChromeBehavior = .default,
        showsMenuBarExtra: Bool = true,
        switcherPlacement: NookModuleSwitcherPlacement = .menuBar,
        presentationPinning: NookPresentationPinning = NookPresentationPinning()
    ) {
        self.registrations = registrations
        self.defaultModuleID = defaultModuleID
        self.cycleHotkey = cycleHotkey
        self.branding = branding
        self.chromeBehavior = chromeBehavior
        self.showsMenuBarExtra = showsMenuBarExtra
        self.switcherPlacement = switcherPlacement
        self.presentationPinning = presentationPinning
        self.filePicker = NookFilePicker(presentationPinning: presentationPinning)
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
        let context = NookModuleContext.makeDefault(
            for: registration.descriptor,
            presentationPinning: presentationPinning,
            filePicker: filePicker
        )
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
