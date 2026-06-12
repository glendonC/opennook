// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import Combine
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
    /// Boots a multi-module notch app: one host process that owns the notch surface and
    /// lets the user switch between the registered ``NookModule``s at runtime.
    ///
    /// The OS calls this from the process's main thread at startup, so we assert that
    /// invariant via `MainActor.assumeIsolated` and run the actual setup on the main actor.
    public static func main(_ host: NookHostConfiguration) {
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate(host: host)
            app.delegate = delegate
            app.setActivationPolicy(.accessory)
            app.run()
            withExtendedLifetime(delegate) {}
        }
    }

    /// Boots a notch app with the given ``NookConfiguration``. The default value
    /// reproduces the framework demo, so `NookApp.main()` is unchanged.
    ///
    /// This is the single-module path: the configuration is registered as the lone
    /// module of a ``NookHostConfiguration``, so a single notch app is just a host with
    /// one module and no switcher.
    public static func main(_ configuration: NookConfiguration = NookConfiguration()) {
        var host = NookHostConfiguration()
        // Forward the single-module path's process-global concerns onto the host that
        // actually owns them: launch seed (appearance / hotkey / display), chrome
        // behavior (hover / shimmer / backdrop), host branding, and the menu-bar flag.
        host.preferenceDefaults = configuration.preferenceDefaults
        host.chromeBehavior = configuration.chromeBehavior
        host.branding = configuration.branding
        host.showsMenuBarExtra = configuration.showsMenuBarExtra
        host.register(
            NookModuleDescriptor(id: ModuleHost.singleModuleID, displayName: "Nook")
        ) { configuration }
        main(host)
    }

    /// "Register a view, go" — boots a notch app whose expanded home surface is the
    /// supplied view. Everything else (top bar, Settings, compact glyphs, theme) keeps
    /// the framework defaults.
    ///
    /// ```swift
    /// NookApp.main { MyHomeView() }
    /// ```
    public static func main<Home: View & Sendable>(
        @ViewBuilder home: @escaping @Sendable @MainActor () -> Home
    ) {
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
    public static func main(_ build: @escaping @Sendable @MainActor () -> NookConfiguration) {
        MainActor.assumeIsolated {
            main(build())
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator: AppCoordinator
    private let moduleHost: ModuleHost
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    init(host: NookHostConfiguration) {
        let moduleHost = ModuleHost(registry: host.makeRegistry())
        self.moduleHost = moduleHost
        // Seed the process-global preferences from the host's launch defaults before the
        // coordinator starts, so the first paint and the initial hotkey registration use
        // them (an `onReady` hook would run too late — after both).
        self.coordinator = AppCoordinator(
            appState: AppState(preferenceDefaults: host.preferenceDefaults),
            moduleHost: moduleHost
        )
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
        // Host opt-out: a host that owns its own menu-bar presence (or wants none) can
        // suppress the framework status item entirely.
        guard moduleHost.showsMenuBarExtra else { return }

        let hostName = moduleHost.branding.hostName
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image =
            moduleHost.branding.menuBarTemplateImage(size: 14)
            ?? NSImage(systemSymbolName: "text.bubble", accessibilityDescription: hostName)
        statusItem = item
        rebuildMenu()

        // The "Settings…" item tracks the active module's `showsSettings`, which can
        // differ across modules — so rebuild the menu whenever the active module changes
        // instead of freezing the launch module's chrome into the menu bar.
        moduleHost.$activeModuleID
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    private func rebuildMenu() {
        guard let statusItem else { return }
        let hostName = moduleHost.branding.hostName

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Show \(hostName)",
            action: #selector(showNook),
            keyEquivalent: ";"
        ))
        // "Settings…" tracks the chrome: dropped when the active module disabled Settings,
        // since there is no Settings UI to open. "Toggle Stay Expanded" is kept regardless
        // — it's chrome-independent and is the only keep-open control left once the top
        // bar (and its lock) is hidden.
        if moduleHost.configuration.topBar.showsSettings {
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

        // Modules — a multi-module host that left switching in the menu bar (the default
        // placement) gets a section here: one item per module, a check on the active one,
        // selecting switches. This keeps switching off the host's expanded surface.
        if moduleHost.switcherPlacement.listsModulesInMenuBar && moduleHost.isMultiModule {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: "Modules"))
            for descriptor in moduleHost.descriptors {
                let moduleItem = NSMenuItem(
                    title: descriptor.displayName,
                    action: #selector(switchToModule(_:)),
                    keyEquivalent: ""
                )
                moduleItem.representedObject = descriptor.id
                moduleItem.state = descriptor.id == moduleHost.activeModuleID ? .on : .off
                moduleItem.image = NSImage(
                    systemSymbolName: descriptor.icon,
                    accessibilityDescription: descriptor.displayName
                )
                menu.addItem(moduleItem)
            }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
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

    @objc private func switchToModule(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        coordinator.switchModule(to: id)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
