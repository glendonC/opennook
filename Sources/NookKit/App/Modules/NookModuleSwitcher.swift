// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// Where a multi-module host surfaces its module switcher.
///
/// Switching is *always* reachable through the module-cycle hotkey and any per-module
/// direct hotkeys; this only governs the on-screen switch affordance. The framework
/// never plants a switcher band in the host's expanded surface uninvited - the default
/// keeps the surface entirely the host's and offers switching from the menu-bar item.
public enum NookModuleSwitcherPlacement: Sendable, Hashable {
    /// No on-screen switcher anywhere. Switching is reachable only through the cycle and
    /// per-module hotkeys. The most hands-off option: neither the expanded surface nor
    /// the menu bar carries anything the host did not put there.
    case none

    /// A "Modules" section in the framework menu-bar item, listing every module and
    /// switching on selection with a check on the active one. Nothing is added to the
    /// expanded surface. This is the default.
    case menuBar

    /// A compact switcher folded into the top bar's leading cluster: the active module's
    /// name and icon become a popup that lists the others. Also lists modules in the menu
    /// bar. Use this when the surface should carry an on-screen switch affordance - it
    /// replaces the leading title rather than adding a band, so it costs no extra height
    /// and never duplicates the active module's identity.
    case leadingCluster

    /// Whether the framework menu-bar item should carry a "Modules" section.
    public var listsModulesInMenuBar: Bool {
        switch self {
        case .none: return false
        case .menuBar, .leadingCluster: return true
        }
    }

    /// Whether the top bar's leading cluster should become a module switcher.
    public var foldsIntoLeadingCluster: Bool {
        self == .leadingCluster
    }
}

/// The data the top bar's leading cluster needs to render an in-surface module switcher,
/// built by the multi-module router when the host opts into
/// ``NookModuleSwitcherPlacement/leadingCluster``. Internal plumbing surfaced through the
/// `public` ``NookExpandedView`` initializer, so the type is `public` too; a single-module
/// host never constructs one (its leading cluster stays the plain title).
public struct NookModuleSwitcher {
    /// Every registered module, in registration order - the popup's list.
    public let modules: [NookModuleDescriptor]

    /// The module currently filling the surface; carries the check in the popup.
    public let activeID: String

    /// Backgrounded modules that asked for attention - badged in the popup.
    public let attentionIDs: Set<String>

    /// Switches the foreground module to `id`. Routed to `AppCoordinator.switchModule`.
    public let switchTo: (String) -> Void

    public init(
        modules: [NookModuleDescriptor],
        activeID: String,
        attentionIDs: Set<String>,
        switchTo: @escaping (String) -> Void
    ) {
        self.modules = modules
        self.activeID = activeID
        self.attentionIDs = attentionIDs
        self.switchTo = switchTo
    }

    /// The descriptor of the active module, used for the cluster's collapsed label.
    public var activeDescriptor: NookModuleDescriptor? {
        modules.first { $0.id == activeID }
    }
}
