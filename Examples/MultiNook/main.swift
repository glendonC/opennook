// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

// MultiNook — one host process, several interchangeable notch apps.
//
// A NookHostConfiguration registers a set of modules; the host shows one at a time and
// the user switches between them through the switcher strip at the top of the expanded
// surface, or with the module-cycle shortcut. Run with `swift run MultiNook`.

import NookApp
import SwiftUI

/// A plain home view shared by the example modules.
struct ModuleHome: View {
    let headline: String
    let detail: String
    let symbol: String
    @Environment(\.nookResolvedTheme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(theme.secondaryLabel)
            Text(headline)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.primaryLabel)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(theme.tertiaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

/// A trivial service whose only job is to be resolved through `AppServices` — the
/// counter module's persistence, lifted behind a type so its views need not know how
/// the count is stored. Not actor-isolated: a `ServiceKey`'s `defaultValue` is
/// nonisolated (the SwiftUI `EnvironmentKey` pattern), so its backing type must be too.
final class LaunchTracker: Sendable {
    let launchCount: Int

    init(launchCount: Int) {
        self.launchCount = launchCount
    }

    /// Builds a tracker from a module's isolated defaults, bumping the persisted count.
    static func bumping(_ defaults: UserDefaults) -> LaunchTracker {
        let next = defaults.integer(forKey: "launchCount") + 1
        defaults.set(next, forKey: "launchCount")
        return LaunchTracker(launchCount: next)
    }

    /// The default used when no `LaunchTracker` was registered for the key.
    static let unregistered = LaunchTracker(launchCount: 0)
}

/// The `ServiceKey` the counter module registers its `LaunchTracker` against. Resolving
/// `LaunchTrackerKey.self` is total — it falls back to `defaultValue` if unregistered.
struct LaunchTrackerKey: ServiceKey {
    static let defaultValue: LaunchTracker = .unregistered
}

/// A module that carries its own product state — a launch counter persisted in the
/// module's isolated `UserDefaults` suite, exposed to its views through the type-safe
/// `AppServices` container keyed by `LaunchTrackerKey`. Shows the full `NookModule`
/// protocol; the simpler modules below register a `NookConfiguration` closure directly.
@MainActor
final class CounterModule: NookModule {
    // `nonisolated` so the top-level (nonisolated) host setup can reference it. The
    // descriptor is an immutable `Sendable` value, so this is safe outside the actor.
    nonisolated static let moduleDescriptor = NookModuleDescriptor(
        id: "com.opennook.example.counter",
        displayName: "Counter",
        icon: "number",
        accent: .orange
    )

    let descriptor = CounterModule.moduleDescriptor
    private let context: NookModuleContext

    init(context: NookModuleContext) {
        self.context = context
        // Build the service from the module's isolated defaults and register it in the
        // module's own `AppServices` bag under its `ServiceKey`. The module's views
        // resolve it back with `services.resolve(LaunchTrackerKey.self)`.
        let tracker = LaunchTracker.bumping(context.defaults)
        context.services.register(LaunchTrackerKey.self, tracker)
    }

    func makeConfiguration() -> NookConfiguration {
        var configuration = NookConfiguration()
        configuration.setHome { CounterHome() }
        configuration.topBar.leadingTitle = { _ in "Counter" }
        configuration.topBar.leadingIcon = "number"
        return configuration
    }
}

/// The counter module's home view. It resolves the launch count out of the module's
/// `AppServices` bag — never optional, thanks to `LaunchTrackerKey.defaultValue`.
struct CounterHome: View {
    @Environment(\.appServices) private var services

    var body: some View {
        let count = services.resolve(LaunchTrackerKey.self).launchCount
        ModuleHome(
            headline: "Counter module",
            detail: "Opened \(count) time\(count == 1 ? "" : "s") — count resolved from this module's AppServices.",
            symbol: "number"
        )
    }
}

@MainActor
func clockConfiguration() -> NookConfiguration {
    var configuration = NookConfiguration()
    configuration.setHome {
        ModuleHome(
            headline: "Clock module",
            detail: "A second notch app sharing the same surface.",
            symbol: "clock"
        )
    }
    configuration.topBar.leadingTitle = { _ in "Clock" }
    configuration.topBar.leadingIcon = "clock"
    return configuration
}

@MainActor
func notesConfiguration() -> NookConfiguration {
    var configuration = NookConfiguration()
    configuration.setHome {
        ModuleHome(
            headline: "Notes module",
            detail: "Switch from the menu-bar Modules section, or press Control-Option-Grave.",
            symbol: "note.text"
        )
    }
    configuration.topBar.leadingTitle = { _ in "Notes" }
    configuration.topBar.leadingIcon = "note.text"
    return configuration
}

var host = NookHostConfiguration()

host.register(CounterModule.moduleDescriptor) { context in
    CounterModule(context: context)
}
host.register(
    NookModuleDescriptor(
        id: "com.opennook.example.clock",
        displayName: "Clock",
        icon: "clock",
        accent: .blue
    ),
    configuration: { clockConfiguration() }
)
host.register(
    NookModuleDescriptor(
        id: "com.opennook.example.notes",
        displayName: "Notes",
        icon: "note.text",
        accent: .green
    ),
    configuration: { notesConfiguration() }
)

// Control-Option-Grave cycles to the next module. (Carbon: controlKey | optionKey.)
host.moduleCycleHotkey = NookHotkey(keyCode: 50, carbonModifiers: 4096 | 2048, keySymbol: "`")
host.defaultModule = CounterModule.moduleDescriptor.id

// Where the switcher lives. The default (.menuBar) keeps the expanded surface entirely
// the module's own and lists modules in the menu-bar item; switch there or with the cycle
// hotkey above. Opt into an on-screen switcher folded into the top bar's leading cluster:
//   host.moduleSwitcherPlacement = .leadingCluster
// or drop the on-screen affordance entirely (hotkeys only):
//   host.moduleSwitcherPlacement = .none

NookApp.main(host)
