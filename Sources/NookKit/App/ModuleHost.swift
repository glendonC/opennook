// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Combine
import SwiftUI

/// The indirection layer between ``AppCoordinator`` and the host-supplied
/// ``NookConfiguration``.
///
/// `AppCoordinator` builds the notch surface exactly once, but a multi-module host
/// swaps which module's content the surface shows at runtime. `ModuleHost` is the
/// single observable seam that makes that possible: the surface's expanded and compact
/// content are *router views* observing this object, so re-publishing
/// ``configuration`` re-renders the surface with the new module's content, theme, and
/// chrome — without rebuilding the `Nook` or its window.
///
/// In a single-module host this object never changes after construction; it still
/// exists so the coordinator has a uniform path to the active configuration.
@MainActor
public final class ModuleHost: ObservableObject {
    /// The configuration whose content currently fills the surface. Re-publishing this
    /// is what a module switch *is* — see `ModuleHost.switch(to:)` (added in Phase 2).
    @Published public private(set) var configuration: NookConfiguration

    public init(configuration: NookConfiguration) {
        self.configuration = configuration
    }

    /// Replaces the active configuration. Phase 0: used only to seed the host. Phase 2
    /// layers module identity, lifecycle hooks, and isolation on top of this primitive.
    func setConfiguration(_ configuration: NookConfiguration) {
        self.configuration = configuration
    }
}
