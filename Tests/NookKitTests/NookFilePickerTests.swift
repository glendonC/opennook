// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest
@testable import NookKit

/// Coverage for the parts of the file picker that run headless: the
/// ``NookFileSelection`` scope-bracket value type and the host wiring that registers a
/// live ``NookFilePicker`` into every module's ``AppServices``.
///
/// The `NSOpenPanel` / `NSSavePanel` presentation itself cannot run in a headless test
/// (it shows real UI and needs an active app), so it is exercised manually against the
/// signed app. The ``NookFilePresenting`` protocol is what lets *module* code that calls
/// the picker be tested with a fake — demonstrated by ``testProtocolSeamAcceptsAFake``.
@MainActor
final class NookFilePickerTests: XCTestCase {
    // MARK: - NookFileSelection

    func testWithAccessRunsBodyAndReturnsItsValue() {
        let urls = [URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")]
        let selection = NookFileSelection(urls: urls)

        var seen: [URL] = []
        let count = selection.withAccess { passed -> Int in
            seen = passed
            return passed.count
        }

        XCTAssertEqual(count, 2)
        XCTAssertEqual(seen, urls, "the body receives exactly the selected URLs")
    }

    func testWithAccessRethrows() {
        struct Boom: Error {}
        let selection = NookFileSelection(urls: [URL(fileURLWithPath: "/tmp/a.txt")])

        XCTAssertThrowsError(try selection.withAccess { _ in throw Boom() })
    }

    func testURLConvenienceReturnsFirstSelected() {
        let first = URL(fileURLWithPath: "/tmp/first")
        let selection = NookFileSelection(urls: [first, URL(fileURLWithPath: "/tmp/second")])

        XCTAssertEqual(selection.url, first)
    }

    func testURLIsNilForEmptySelection() {
        XCTAssertNil(NookFileSelection(urls: []).url)
    }

    // MARK: - Host wiring

    /// A module's resolved picker is the registry's single shared instance — not the
    /// inert default — so it can actually present and hold the surface.
    func testModuleContextResolvesTheRegistrySharedPicker() {
        let registry = makeRegistry(ids: ["A"])
        let resolved = registry.context(for: "A")?.services.resolve(NookFilePickerKey.self)

        let resolvedPicker = resolved as? NookFilePicker
        XCTAssertNotNil(resolvedPicker, "resolves to a live NookFilePicker, not the inert default")
        XCTAssertTrue(resolvedPicker === registry.filePicker, "every module shares the one process-wide picker")
    }

    /// Two modules in the same host resolve the same picker instance — the guarantee
    /// that lets it serialize presentation process-wide.
    func testAllModulesShareOnePicker() {
        let registry = makeRegistry(ids: ["A", "B"])
        let a = registry.context(for: "A")?.services.resolve(NookFilePickerKey.self) as? NookFilePicker
        let b = registry.context(for: "B")?.services.resolve(NookFilePickerKey.self) as? NookFilePicker

        XCTAssertNotNil(a)
        XCTAssertTrue(a === b)
    }

    /// An `AppServices` that never went through the host registry falls back to the
    /// inert default — total resolution, never `nil`, and not a live picker.
    func testUnregisteredServicesResolveToInertDefault() {
        let resolved = AppServices().resolve(NookFilePickerKey.self)
        XCTAssertNil(resolved as? NookFilePicker, "the default is the inert stand-in, not a real picker")
    }

    /// Module code that depends on ``NookFilePresenting`` can be tested with a fake,
    /// since the real picker can't run headless.
    func testProtocolSeamAcceptsAFake() async {
        let fake = FakeFilePicker(result: [URL(fileURLWithPath: "/tmp/picked")])
        let selection = await fake.open(.init())

        XCTAssertEqual(selection?.urls, [URL(fileURLWithPath: "/tmp/picked")])
    }

    // MARK: - Fixtures

    private func makeRegistry(ids: [String]) -> NookModuleRegistry {
        var config = NookHostConfiguration()
        for id in ids {
            config.register(NookModuleDescriptor(id: id, displayName: id)) { _ in StubModule(id: id) }
        }
        config.defaultModule = ids.first
        return config.makeRegistry()
    }

    private final class StubModule: NookModule {
        let descriptor: NookModuleDescriptor
        init(id: String) { descriptor = NookModuleDescriptor(id: id, displayName: id) }
        func makeConfiguration() -> NookConfiguration { NookConfiguration() }
        func prepareForSwitchAway() async {}
    }

    private struct FakeFilePicker: NookFilePresenting {
        let result: [URL]
        func open(_ options: NookOpenOptions) async -> NookFileSelection? {
            result.isEmpty ? nil : NookFileSelection(urls: result)
        }
        func save(_ options: NookSaveOptions) async -> NookFileSelection? {
            result.isEmpty ? nil : NookFileSelection(urls: result)
        }
    }
}
