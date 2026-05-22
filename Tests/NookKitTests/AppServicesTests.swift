// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest
@testable import NookKit

final class AppServicesTests: XCTestCase {
    private final class Clipboard {
        var contents: String
        init(contents: String) { self.contents = contents }
    }

    private struct ClipboardKey: ServiceKey {
        static let defaultValue = Clipboard(contents: "default")
    }

    private struct CountKey: ServiceKey {
        static let defaultValue = 0
    }

    func testResolveReturnsRegisteredValue() {
        let services = AppServices()
        services.register(ClipboardKey.self, Clipboard(contents: "hello"))

        XCTAssertEqual(services.resolve(ClipboardKey.self).contents, "hello")
    }

    func testResolveFallsBackToDefaultWhenUnregistered() {
        let services = AppServices()

        XCTAssertEqual(services.resolve(ClipboardKey.self).contents, "default")
        XCTAssertEqual(services.resolve(CountKey.self), 0, "value-typed key resolves to its default")
    }

    func testSubscriptReadsDefaultAndWritesValue() {
        let services = AppServices()
        XCTAssertEqual(services[CountKey.self], 0)

        services[CountKey.self] = 42
        XCTAssertEqual(services[CountKey.self], 42)
        XCTAssertEqual(services.resolve(CountKey.self), 42)
    }

    func testTwoKeysAreIndependent() {
        let services = AppServices()
        services.register(ClipboardKey.self, Clipboard(contents: "x"))
        services.register(CountKey.self, 7)

        XCTAssertEqual(services.resolve(ClipboardKey.self).contents, "x")
        XCTAssertEqual(services.resolve(CountKey.self), 7)
    }

    /// The subscript `set` deliberately replaces a value without tripping the
    /// double-register assertion.
    func testSubscriptSetReplacesWithoutTrapping() {
        let services = AppServices()
        services.register(CountKey.self, 1)
        services[CountKey.self] = 2

        XCTAssertEqual(services.resolve(CountKey.self), 2)
    }
}
