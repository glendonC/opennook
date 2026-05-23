// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Combine
import SwiftUI

/// The indirection layer between ``AppCoordinator`` and the active ``NookModule``.
///
/// `AppCoordinator` builds the notch surface exactly once, but a multi-module host
/// swaps which module's content the surface shows at runtime. `ModuleHost` is the
/// single observable seam that makes that possible: the surface's expanded and compact
/// content are *router views* observing this object, so re-publishing
/// ``configuration`` re-renders the surface with the new module's content, theme, and
/// chrome — without rebuilding the `Nook` or its window.
///
/// In a single-module host the active module never changes; the object still exists so
/// the coordinator has a uniform path to the active configuration and context.
@MainActor
public final class ModuleHost: ObservableObject {
    /// All registered modules and their lazily-built instances.
    public let registry: NookModuleRegistry

    /// The id of the module whose content currently fills the surface.
    @Published public private(set) var activeModuleID: String

    /// The active module's surface configuration — home/compact content, theme, chrome
    /// opt-outs, lifecycle hooks. Re-publishing this is what a module switch *is*; the
    /// router views observe it.
    @Published public private(set) var configuration: NookConfiguration

    public init(registry: NookModuleRegistry) {
        self.registry = registry
        let id = registry.defaultModuleID
        self.activeModuleID = id
        self.configuration = registry.module(for: id)?.makeConfiguration() ?? NookConfiguration()
    }

    /// Single-module convenience — wraps one ``NookConfiguration`` as a lone module so
    /// the existing `NookApp.main(_:)` entry points stay a special case of the host.
    public convenience init(configuration: NookConfiguration) {
        var host = NookHostConfiguration()
        host.register(
            NookModuleDescriptor(id: ModuleHost.singleModuleID, displayName: "Nook")
        ) { configuration }
        self.init(registry: host.makeRegistry())
    }

    /// Descriptor id used for the implicit lone module of a single-configuration host.
    public nonisolated static let singleModuleID = "opennook.module.default"

    /// All registered modules' descriptors, in registration order.
    public var descriptors: [NookModuleDescriptor] { registry.descriptors }

    /// The live active module, constructed on first access.
    public var activeModule: NookModule? { registry.module(for: activeModuleID) }

    /// The active module's isolated context.
    public var activeContext: NookModuleContext? { registry.context(for: activeModuleID) }

    /// The active module's service bag — what the surface binds to `\.appServices`.
    /// Falls back to an empty bag in the impossible case that no context can be resolved
    /// (the active module is always registered, so in practice this branch is unreachable).
    public var activeServices: AppServices { activeContext?.services ?? AppServices() }

    /// `true` when more than one module is registered — i.e. a switcher is meaningful.
    public var isMultiModule: Bool { registry.descriptors.count > 1 }

    /// Optional global shortcut that cycles modules, as configured by the host.
    public var cycleHotkey: NookHotkey? { registry.cycleHotkey }

    /// Modules that want the user's attention while in the background — the switcher
    /// badges these. A backgrounded module (or a component running on its behalf) calls
    /// ``requestAttention(for:)``; switching to a module clears its badge.
    @Published public private(set) var attentionModuleIDs: Set<String> = []

    /// Flags `moduleID` as wanting attention. Ignored for the foreground module — it is
    /// already on screen, so there is nothing to badge.
    public func requestAttention(for moduleID: String) {
        guard moduleID != activeModuleID else { return }
        attentionModuleIDs.insert(moduleID)
    }

    /// Clears the attention badge for `moduleID`.
    public func clearAttention(for moduleID: String) {
        attentionModuleIDs.remove(moduleID)
    }

    /// Switches the foreground module: deactivates the outgoing module, activates and
    /// re-configures the incoming one, and unloads the outgoing module when its
    /// ``NookModuleDescriptor/backgroundPolicy`` is `.unloadOnSwitchAway`.
    ///
    /// This is pure module bookkeeping. The surface-side effects of a switch — re-wiring
    /// the `Nook`'s lifecycle hooks, the once-per-module `onReady`, the synthetic
    /// `onExpand` — are ``AppCoordinator``'s, driven off the `$configuration` re-publish.
    ///
    /// Returns `false` without changing anything when `id` is unregistered or already
    /// the active module.
    @discardableResult
    func switchModule(to id: String) -> Bool {
        let outgoingID = activeModuleID
        guard id != outgoingID, registry.descriptor(for: id) != nil else { return false }
        guard let incoming = registry.module(for: id) else { return false }

        let outgoingDescriptor = registry.descriptor(for: outgoingID)
        registry.module(for: outgoingID)?.onDeactivate()

        incoming.onActivate()
        activeModuleID = id
        attentionModuleIDs.remove(id)
        configuration = incoming.makeConfiguration()

        if outgoingDescriptor?.backgroundPolicy == .unloadOnSwitchAway {
            registry.unload(outgoingID)
        }
        return true
    }
}
