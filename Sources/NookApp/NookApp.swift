// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import SwiftUI

// Re-exported so a host app needs only `import NookApp` to reach the registration API
// (`NookConfiguration`, `NookResolvedTheme`, `AppState`, …) and the surface types.
@_exported import NookKit
@_exported import NookSurface

/// Library entry point shared by the SPM executable trampoline
/// (`Sources/NookExecutable/main.swift`) and the Xcode app target's
/// `App/main.swift`. Both call into the same boot sequence here so behavior
/// cannot drift between launch surfaces.
public enum NookApp {
    /// Boots a notch app with the given ``NookConfiguration``. The default value
    /// reproduces the framework demo, so `NookApp.main()` is unchanged.
    ///
    /// The OS calls this from the process's main thread at startup, so we assert that
    /// invariant via `MainActor.assumeIsolated` and run the actual setup on the main actor.
    public static func main(_ configuration: NookConfiguration = NookConfiguration()) {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate(configuration: configuration)
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            app.run()
            withExtendedLifetime(delegate) {}
        }
    }

    /// "Register a view, go" — boots a notch app whose expanded home surface is the
    /// supplied view. Everything else (top bar, Settings, compact glyphs, theme) keeps
    /// the framework defaults.
    ///
    /// ```swift
    /// NookApp.main { MyHomeView() }
    /// ```
    public static func main<Home: View>(@ViewBuilder home: @escaping () -> Home) {
        var configuration = NookConfiguration()
        configuration.setHome(home)
        main(configuration)
    }

    /// Boots a notch app, building the ``NookConfiguration`` on the main actor.
    ///
    /// Use this overload when setup constructs main-actor-isolated types — a
    /// `NookComponents` `ShelfStore` or `NookActivityQueue`, a host view model — which
    /// can't be created from the (non-isolated) top level of a `main.swift`:
    ///
    /// ```swift
    /// NookApp.main {
    ///     let queue = NookActivityQueue()
    ///     var configuration = NookConfiguration()
    ///     configuration.setHome { NookActivityHost(queue: queue) { MyHome() } }
    ///     configuration.onReady = { queue.bind(to: $0) }
    ///     return configuration
    /// }
    /// ```
    public static func main(_ build: @MainActor () -> NookConfiguration) {
        MainActor.assumeIsolated {
            main(build())
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator: AppCoordinator
    private let configuration: NookConfiguration
    private var statusItem: NSStatusItem?

    init(configuration: NookConfiguration) {
        self.configuration = configuration
        self.coordinator = AppCoordinator(configuration: configuration)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
        installMenuBarFallback()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func installMenuBarFallback() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Nook")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Show Nook",
            action: #selector(showNook),
            keyEquivalent: ";"
        ))
        // "Settings…" tracks the chrome: dropped when the host disabled Settings, since
        // there is no Settings UI to open. "Toggle Stay Expanded" is kept regardless —
        // it's chrome-independent and is the only keep-open control left once the top
        // bar (and its lock) is hidden.
        if configuration.showsSettings {
            menu.addItem(NSMenuItem(
                title: "Settings…",
                action: #selector(showSettings),
                keyEquivalent: ","
            ))
        }
        menu.addItem(NSMenuItem(
            title: "Toggle Stay Expanded",
            action: #selector(toggleKeepOpen),
            keyEquivalent: "k"
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func showNook() {
        coordinator.showNook()
    }

    @objc private func showSettings() {
        coordinator.showSettings()
    }

    @objc private func toggleKeepOpen() {
        coordinator.toggleKeepNookOpen()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
