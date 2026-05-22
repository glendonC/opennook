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
    /// router views observe it. (`switch(to:)` arrives in Phase 2.)
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

    /// `true` when more than one module is registered — i.e. a switcher is meaningful.
    public var isMultiModule: Bool { registry.descriptors.count > 1 }
}
