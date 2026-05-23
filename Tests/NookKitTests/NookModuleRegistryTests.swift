// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest
@testable import NookKit

/// Direct coverage for ``NookModuleRegistry`` — lazy construction, instance caching,
/// `isLoaded` / `unload` lifecycle, descriptor lookup. The registry is the only piece
/// that *retains* live module instances; getting this wrong leaks state across
/// switches.
@MainActor
final class NookModuleRegistryTests: XCTestCase {
    /// A minimal module that counts factory invocations so the tests can prove the
    /// registry's caching/unload behavior.
    private final class CountingModule: NookModule {
        let descriptor: NookModuleDescriptor
        init(id: String) {
            descriptor = NookModuleDescriptor(id: id, displayName: id, backgroundPolicy: .stayResident)
        }
        func makeConfiguration() -> NookConfiguration { NookConfiguration() }
        func prepareForSwitchAway() async {}
    }

    /// Counts factory calls per id so caching/unload effects are observable.
    private final class FactoryProbe: @unchecked Sendable {
        var counts: [String: Int] = [:]
        func record(_ id: String) {
            counts[id, default: 0] += 1
        }
    }

    private func makeRegistry(ids: [String], probe: FactoryProbe = FactoryProbe()) -> (NookModuleRegistry, FactoryProbe) {
        var config = NookHostConfiguration()
        for id in ids {
            let descriptor = NookModuleDescriptor(id: id, displayName: id)
            let p = probe
            config.register(descriptor) { _ in
                p.record(id)
                return CountingModule(id: id)
            }
        }
        config.defaultModule = ids.first
        return (config.makeRegistry(), probe)
    }

    // MARK: - Lazy construction + caching

    /// `isLoaded` is `false` before a module is first accessed.
    func testIsLoadedFalseBeforeFirstAccess() {
        let (registry, _) = makeRegistry(ids: ["A", "B"])
        XCTAssertFalse(registry.isLoaded("A"))
        XCTAssertFalse(registry.isLoaded("B"))
    }

    /// A first `module(for:)` constructs and caches the module — `isLoaded` flips
    /// `true`, the factory ran exactly once.
    func testModuleForBuildsAndCachesOnFirstAccess() {
        let (registry, probe) = makeRegistry(ids: ["A"])
        let first = registry.module(for: "A")
        XCTAssertNotNil(first)
        XCTAssertTrue(registry.isLoaded("A"))
        XCTAssertEqual(probe.counts["A"], 1)
    }

    /// A second `module(for:)` returns the same cached instance — the factory does
    /// not re-run.
    func testModuleForReturnsSameInstanceOnSubsequentCalls() {
        let (registry, probe) = makeRegistry(ids: ["A"])
        let first = registry.module(for: "A")
        let second = registry.module(for: "A")
        XCTAssertTrue(first === second, "cached instance is reused")
        XCTAssertEqual(probe.counts["A"], 1, "factory did not run twice")
    }

    /// An unregistered id resolves to `nil`, never traps.
    func testModuleForUnknownIDReturnsNil() {
        let (registry, _) = makeRegistry(ids: ["A"])
        XCTAssertNil(registry.module(for: "ghost"))
        XCTAssertFalse(registry.isLoaded("ghost"))
    }

    // MARK: - Unload lifecycle

    /// `unload(_:)` drops the cached instance — the next `module(for:)` rebuilds it.
    func testUnloadDropsCachedInstanceAndForcesRebuild() {
        let (registry, probe) = makeRegistry(ids: ["A"])
        _ = registry.module(for: "A")
        XCTAssertEqual(probe.counts["A"], 1)

        registry.unload("A")
        XCTAssertFalse(registry.isLoaded("A"))

        let rebuilt = registry.module(for: "A")
        XCTAssertNotNil(rebuilt)
        XCTAssertEqual(probe.counts["A"], 2, "second build is a fresh instance, not the dropped one")
    }

    /// `unload(_:)` on an unregistered or never-built id is a silent no-op.
    func testUnloadOnUnknownIDIsNoOp() {
        let (registry, _) = makeRegistry(ids: ["A"])
        registry.unload("ghost")  // never registered
        registry.unload("A")      // registered but never built
        XCTAssertFalse(registry.isLoaded("A"))
    }

    /// Unloading also drops the cached context, so a rebuilt module gets a fresh one.
    func testUnloadDropsContextSoRebuildGetsAFreshOne() {
        let (registry, _) = makeRegistry(ids: ["A"])
        let firstContext = registry.context(for: "A")
        XCTAssertNotNil(firstContext)

        registry.unload("A")
        let secondContext = registry.context(for: "A")
        XCTAssertNotNil(secondContext)
        XCTAssertFalse(firstContext === secondContext, "fresh context after unload + rebuild")
    }

    // MARK: - Descriptor lookup

    /// `descriptor(for:)` returns the registered descriptor; `descriptors` is in
    /// registration order.
    func testDescriptorLookupAndOrder() {
        let (registry, _) = makeRegistry(ids: ["A", "B", "C"])
        XCTAssertEqual(registry.descriptors.map(\.id), ["A", "B", "C"])
        XCTAssertEqual(registry.descriptor(for: "B")?.id, "B")
        XCTAssertNil(registry.descriptor(for: "ghost"))
    }

    /// `defaultModuleID` matches the host's explicit choice when it's registered.
    func testDefaultModuleIDHonorsExplicitChoice() {
        var config = NookHostConfiguration()
        config.register(NookModuleDescriptor(id: "A", displayName: "A")) { _ in CountingModule(id: "A") }
        config.register(NookModuleDescriptor(id: "B", displayName: "B")) { _ in CountingModule(id: "B") }
        config.defaultModule = "B"

        XCTAssertEqual(config.makeRegistry().defaultModuleID, "B")
    }

    /// An explicit default that isn't registered falls back to the first registered.
    func testDefaultModuleIDFallsBackToFirstWhenChoiceUnknown() {
        var config = NookHostConfiguration()
        config.register(NookModuleDescriptor(id: "A", displayName: "A")) { _ in CountingModule(id: "A") }
        config.register(NookModuleDescriptor(id: "B", displayName: "B")) { _ in CountingModule(id: "B") }
        config.defaultModule = "ghost"

        XCTAssertEqual(config.makeRegistry().defaultModuleID, "A")
    }
}
