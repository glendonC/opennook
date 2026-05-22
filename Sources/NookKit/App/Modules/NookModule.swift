// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// A self-contained notch app that can coexist with other modules in one host process
/// and be swapped onto the shared surface at runtime.
///
/// A module owns its home view, compact slots, theme, lifecycle hooks (all expressed
/// through the ``NookConfiguration`` it produces) and its product state and services
/// (held as stored properties — the module instance *is* its own dependency container).
///
/// A module is built by its factory with an isolated ``NookModuleContext``; conventionally
/// it captures the context and persists through `context.defaults` / `context.containerURL`.
/// ``onActivate()`` / ``onDeactivate()`` bracket the spans where the module is the
/// foreground module filling the surface.
@MainActor
public protocol NookModule: AnyObject {
    /// The module's registration-time identity. Must equal the descriptor it was
    /// registered with.
    var descriptor: NookModuleDescriptor { get }

    /// Builds the surface configuration — home/compact content, theme, chrome opt-outs,
    /// lifecycle hooks. Called when the module becomes active; the result is cached by
    /// the host until the next activation.
    func makeConfiguration() -> NookConfiguration

    /// Called when the module becomes the foreground module. The surface is about to
    /// show this module's content.
    func onActivate()

    /// Called when the user switches away. The module's content is no longer on the
    /// surface; depending on ``NookModuleDescriptor/backgroundPolicy`` the instance may
    /// be torn down after this returns.
    func onDeactivate()
}

public extension NookModule {
    func onActivate() {}
    func onDeactivate() {}
}

/// Adapts a plain ``NookConfiguration`` into a ``NookModule``.
///
/// This is what makes the single-module path a special case of the multi-module host:
/// `NookApp.main(someConfiguration)` registers exactly one `ClosureModule`. It is also
/// the simplest way to register a module that has no product state beyond its views.
@MainActor
public final class ClosureModule: NookModule {
    public let descriptor: NookModuleDescriptor
    private let build: @MainActor () -> NookConfiguration

    public init(descriptor: NookModuleDescriptor, build: @escaping @MainActor () -> NookConfiguration) {
        self.descriptor = descriptor
        self.build = build
    }

    public func makeConfiguration() -> NookConfiguration {
        build()
    }
}
