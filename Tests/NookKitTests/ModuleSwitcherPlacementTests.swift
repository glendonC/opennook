// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest
@testable import NookKit

/// Coverage for ``NookModuleSwitcherPlacement`` and the host->registry->ModuleHost flow
/// that decides where (if anywhere) the module switcher appears. The view layer that
/// reads these (the menu-bar section and the leading-cluster popup) is exercised by
/// running `MultiNook`; this pins the policy underneath it.
@MainActor
final class ModuleSwitcherPlacementTests: XCTestCase {
    private func makeHost(
        placement: NookModuleSwitcherPlacement? = nil,
        moduleIDs: [String] = ["A", "B"]
    ) -> ModuleHost {
        var config = NookHostConfiguration()
        if let placement { config.moduleSwitcherPlacement = placement }
        for id in moduleIDs {
            config.register(NookModuleDescriptor(id: id, displayName: id)) { NookConfiguration() }
        }
        return ModuleHost(registry: config.makeRegistry())
    }

    // MARK: - Enum policy

    func testNonePlacementShowsNothing() {
        XCTAssertFalse(NookModuleSwitcherPlacement.none.listsModulesInMenuBar)
        XCTAssertFalse(NookModuleSwitcherPlacement.none.foldsIntoLeadingCluster)
    }

    func testMenuBarPlacementListsInMenuBarOnly() {
        XCTAssertTrue(NookModuleSwitcherPlacement.menuBar.listsModulesInMenuBar)
        XCTAssertFalse(NookModuleSwitcherPlacement.menuBar.foldsIntoLeadingCluster)
    }

    func testLeadingClusterPlacementFoldsInAndAlsoListsInMenuBar() {
        XCTAssertTrue(NookModuleSwitcherPlacement.leadingCluster.foldsIntoLeadingCluster)
        XCTAssertTrue(NookModuleSwitcherPlacement.leadingCluster.listsModulesInMenuBar)
    }

    // MARK: - Host -> ModuleHost flow

    /// The framework never plants switcher chrome in the host surface uninvited: the
    /// default is `.menuBar`, so an unconfigured multi-module host gets a menu-bar list
    /// and a clean expanded surface.
    func testDefaultPlacementIsMenuBar() {
        XCTAssertEqual(makeHost().switcherPlacement, .menuBar)
        XCTAssertFalse(makeHost().switcherPlacement.foldsIntoLeadingCluster)
    }

    func testConfiguredPlacementFlowsThroughRegistryToModuleHost() {
        XCTAssertEqual(makeHost(placement: .leadingCluster).switcherPlacement, .leadingCluster)
        // Fully qualified: in this `Optional<NookModuleSwitcherPlacement>` parameter
        // context a bare `.none` would bind to `Optional.none` (nil), not the enum case.
        XCTAssertEqual(makeHost(placement: NookModuleSwitcherPlacement.none).switcherPlacement, .none)
    }

    // MARK: - Switcher model

    func testActiveDescriptorResolvesFromActiveID() {
        let modules = [
            NookModuleDescriptor(id: "A", displayName: "Alpha"),
            NookModuleDescriptor(id: "B", displayName: "Beta")
        ]
        let switcher = NookModuleSwitcher(
            modules: modules,
            activeID: "B",
            attentionIDs: [],
            switchTo: { _ in }
        )
        XCTAssertEqual(switcher.activeDescriptor?.displayName, "Beta")
    }
}
