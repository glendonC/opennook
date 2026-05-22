// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import Combine
import NookSurface
import SwiftUI

/// App-wide coordinator. Owns the long-running state, constructs the notch chrome,
/// and exposes the lifecycle vocabulary (show/hide/toggle, reset-settings) that views
/// and the menu-bar fallback call into.
@MainActor
public final class AppCoordinator: ObservableObject {
    public let appState: AppState

    /// The indirection layer to the active host configuration. The surface's content
    /// observes this, so a module switch is a re-publish here rather than a rebuild.
    public let moduleHost: ModuleHost

    /// Host-supplied registration: home/compact content, theme, lifecycle hooks.
    /// Reads through ``moduleHost`` so it always reflects the active module.
    public var configuration: NookConfiguration { moduleHost.configuration }

    enum NookAppearance {
        static let expandedTopCornerRadius: CGFloat = 19
        static let expandedBottomCornerRadius: CGFloat = 24
    }

    let hotkeyController: HotkeyController
    var cancellables = Set<AnyCancellable>()
    var accessibilityObserver: NSObjectProtocol?

    /// Arbitrates the surface between competing transient presenters — the activity
    /// queues and ambient indicators of every loaded module. Lazy because it captures
    /// `nook`; layered over ``enqueueLifecycle`` so it serializes nothing itself.
    lazy var arbiter: SurfaceArbiter = {
        SurfaceArbiter(
            isUserEngaged: { [weak self] in self?.isUserEngaged ?? false },
            activeModuleID: { [weak self] in self?.moduleHost.activeModuleID ?? "" },
            currentState: { [weak self] in self?.nook.state ?? .hidden },
            runSerial: { [weak self] operation in
                await self?.enqueueLifecycle(operation).value
            },
            expand: { [weak self] in await self?.nook.expand() },
            compact: { [weak self] in await self?.nook.compact() },
            hide: { [weak self] in await self?.nook.hide() }
        )
    }()

    /// `true` once ``start()`` has run. Guards against a double `start()` registering
    /// duplicate observers, sinks, and `onReady` callbacks.
    private var hasStarted = false

    /// Module ids whose `onReady` has already fired. A module's `onReady` runs once per
    /// *loaded instance* — when it is unloaded (`unloadOnSwitchAway`) the id is dropped
    /// so a rebuilt instance gets a fresh `onReady` (e.g. to re-bind an activity queue).
    private var modulesGivenOnReady: Set<String> = []

    /// Tail of the serial chain that all surface lifecycle transitions
    /// (expand/compact/hide) run through. Without this, two rapid triggers — a
    /// double hotkey press, a display change landing mid-show — each spawn an
    /// independent `Task` whose `await`s interleave, settling the surface in the
    /// opposite state from the user's last action.
    private var lifecycleTail: Task<Void, Never>?

    /// Chains `operation` after every previously enqueued lifecycle transition so
    /// they run strictly in order. The returned task completes when `operation` does.
    @discardableResult
    func enqueueLifecycle(_ operation: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let previous = lifecycleTail
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        lifecycleTail = task
        return task
    }

    lazy var nook: Nook<AnyView, AnyView, AnyView> = {
        let nook = Nook<AnyView, AnyView, AnyView>(
            hoverBehavior: [],
            style: NookStyle(
                topCornerRadius: NookAppearance.expandedTopCornerRadius,
                bottomCornerRadius: NookAppearance.expandedBottomCornerRadius
            ),
            expanded: {
                AnyView(ModuleRouterExpandedView(
                    moduleHost: self.moduleHost,
                    appState: self.appState,
                    toggleKeepOpen: { [weak self] in self?.toggleKeepNookOpen() },
                    hide: { [weak self] in self?.hideNook() },
                    resetAllSettings: { [weak self] in self?.resetAllSettingsToDefaults() }
                ))
            },
            compactLeading: {
                AnyView(ModuleRouterCompactView(
                    moduleHost: self.moduleHost,
                    appState: self.appState,
                    slot: .leading
                ))
            },
            compactTrailing: {
                AnyView(ModuleRouterCompactView(
                    moduleHost: self.moduleHost,
                    appState: self.appState,
                    slot: .trailing
                ))
            }
        )
        // Project the active module's lifecycle callbacks onto the surface. The hooks
        // fire on the surface's own state transitions, so hover- and drag-driven changes
        // reach the host too — not just coordinator-initiated show/hide. `bindModuleHost`
        // keeps these in sync across a module switch.
        nook.onExpand = self.configuration.onExpand
        nook.onCompact = self.configuration.onCompact
        nook.onHide = self.configuration.onHide
        return nook
    }()

    public convenience init(
        appState: AppState = AppState(),
        hotkeyController: HotkeyController = HotkeyController(),
        configuration: NookConfiguration = NookConfiguration()
    ) {
        self.init(
            appState: appState,
            hotkeyController: hotkeyController,
            moduleHost: ModuleHost(configuration: configuration)
        )
    }

    public init(
        appState: AppState = AppState(),
        hotkeyController: HotkeyController = HotkeyController(),
        moduleHost: ModuleHost
    ) {
        self.appState = appState
        self.hotkeyController = hotkeyController
        self.moduleHost = moduleHost

        bindBackdropSynchronization()
    }

    deinit {
        if let accessibilityObserver {
            NotificationCenter.default.removeObserver(accessibilityObserver)
        }
    }

    public func start() {
        guard !hasStarted else { return }
        hasStarted = true

        NSApp.setActivationPolicy(.accessory)

        syncNotchBackdrop()
        configureNotchAnimations()
        configureDisplayTargeting()

        registerGlobalHotkey()
        bindHotkeyRegistration()
        bindNookDragSession()
        bindSurfaceVisibility()
        bindModuleHost()

        // Cold-launch greeting: compact the chrome, then fire a one-shot shimmer along the
        // perimeter so the user sees the app is awake. Awaiting `compact()` first puts the
        // nook into a visible state so the event fires immediately instead of queuing.
        enqueueLifecycle { [weak self] in
            guard let self else { return }
            await self.nook.compact(on: self.resolveScreen())
            self.nook.playFeedback(.shimmer, duration: 1.1)
        }

        // Hand the host a post-launch handle on the live coordinator (e.g. for
        // NookComponents' activity queue to bind itself as a transient presenter).
        fireModuleReadyIfNeeded()
    }

    // MARK: - Module switching

    /// The registered modules available to switch between, in registration order.
    public var moduleDescriptors: [NookModuleDescriptor] { moduleHost.descriptors }

    /// The id of the foreground module.
    public var activeModuleID: String { moduleHost.activeModuleID }

    /// Switches the foreground module and runs the surface-side effects of the switch:
    /// the `Nook`'s lifecycle hooks re-wire via the `$configuration` observer, the
    /// incoming module gets a once-per-instance `onReady`, and — when the surface is
    /// already expanded — a synthetic `onExpand` so the new content sees a consistent
    /// lifecycle. The content cross-fades in place; the surface is not hidden, so the
    /// outgoing module gets `onDeactivate` (via `ModuleHost`) but not `onHide`.
    public func switchModule(to id: String) {
        let outgoingID = moduleHost.activeModuleID
        guard id != outgoingID else { return }

        let wasExpanded = nook.state == .expanded
        withAnimation(.easeInOut(duration: 0.22)) {
            _ = moduleHost.switchModule(to: id)
        }
        guard moduleHost.activeModuleID == id else { return }

        // An unloaded module is rebuilt fresh on return, so its `onReady` must fire again.
        if !moduleHost.registry.isLoaded(outgoingID) {
            modulesGivenOnReady.remove(outgoingID)
        }
        fireModuleReadyIfNeeded()
        if wasExpanded {
            moduleHost.configuration.onExpand?()
        }
    }

    /// Switches to the next registered module, wrapping around. No-op for a host with a
    /// single module.
    public func cycleModule() {
        let ids = moduleHost.descriptors.map(\.id)
        guard ids.count > 1, let index = ids.firstIndex(of: moduleHost.activeModuleID) else { return }
        switchModule(to: ids[(index + 1) % ids.count])
    }

    /// Fires the active module's `onReady` once per loaded instance.
    private func fireModuleReadyIfNeeded() {
        let id = moduleHost.activeModuleID
        guard !modulesGivenOnReady.contains(id) else { return }
        modulesGivenOnReady.insert(id)
        moduleHost.configuration.onReady?(self)
    }

    /// Re-wires the `Nook`'s lifecycle hooks whenever the active module changes. The
    /// initial wiring is done eagerly in the `nook` builder; this handles every switch
    /// after launch. Theme and chrome opt-outs need no rewiring — the router views
    /// re-read them from `moduleHost` on each layout pass.
    private func bindModuleHost() {
        moduleHost.$configuration
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] configuration in
                guard let self else { return }
                self.nook.onExpand = configuration.onExpand
                self.nook.onCompact = configuration.onCompact
                self.nook.onHide = configuration.onHide
                self.nook.onFileDrop = configuration.onFileDrop ?? { _ in false }
            }
            .store(in: &cancellables)
    }

    // MARK: - Display targeting

    /// Resolve the user's persisted display preference to a concrete screen.
    /// `nil` only when no display is attached at all.
    func resolveScreen() -> NSScreen? {
        NookScreenLocator.screen(matching: appState.displayPreference)
    }

    /// Project the persisted display preference onto the surface, and re-place the
    /// chrome live when the user picks a different display in Settings.
    ///
    /// `Nook.screenProvider` is what makes the preference stick *without* an explicit
    /// screen on every call site — the surface consults it on hover transitions and on
    /// display connect/disconnect too, so the disconnect fallback in
    /// ``NookScreenLocator/screen(matching:)`` flows through automatically.
    private func configureDisplayTargeting() {
        nook.screenProvider = { [weak self] in self?.resolveScreen() }

        appState.$displayPreference
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] preference in
                guard let self else { return }
                let screen = NookScreenLocator.screen(matching: preference)
                self.enqueueLifecycle { [weak self] in
                    guard let self else { return }
                    // Re-place whichever way the chrome is currently showing. A hidden
                    // nook needs nothing — its next expand/compact rebuilds on the new
                    // screen via `screenProvider`.
                    if self.nook.state == .expanded {
                        await self.nook.expand(on: screen)
                    } else if self.nook.windowController != nil {
                        await self.nook.compact(on: screen)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Chrome / backdrop

    /// Softer springs than NookSurface's bouncy defaults — smoother expand/compact with
    /// less overshoot.
    func configureNotchAnimations() {
        nook.transitionConfiguration.openingAnimation = .spring(
            response: 0.52, dampingFraction: 0.88, blendDuration: 0.12
        )
        nook.transitionConfiguration.closingAnimation = .spring(
            response: 0.46, dampingFraction: 0.93, blendDuration: 0.10
        )
        nook.transitionConfiguration.conversionAnimation = .spring(
            response: 0.54, dampingFraction: 0.86, blendDuration: 0.12
        )
    }

    // MARK: - Global hotkey

    /// Registers the current `appState.hotkey` as the global show/hide shortcut.
    /// Skipped while the user is mid-recording so the old shortcut can't fire.
    func registerGlobalHotkey() {
        guard !appState.isRecordingHotkey else { return }

        let hotkey = appState.hotkey
        let status = hotkeyController.register(
            keyCode: hotkey.keyCode,
            modifiers: hotkey.carbonModifiers
        ) { [weak self] in
            Task { @MainActor in
                self?.toggleNook()
            }
        }
        if status != noErr {
            appState.errorMessage = "That shortcut is unavailable — another app may be using it."
        } else {
            // Clear any earlier failure once a registration succeeds.
            appState.errorMessage = nil
        }
    }

    /// Keeps the live hotkey registration in sync with `appState`: re-register when the
    /// user picks a new shortcut, and suspend registration entirely while recording.
    private func bindHotkeyRegistration() {
        appState.$hotkey
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.registerGlobalHotkey() }
            .store(in: &cancellables)

        appState.$isRecordingHotkey
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] isRecording in
                guard let self else { return }
                if isRecording {
                    self.hotkeyController.unregister()
                } else {
                    self.registerGlobalHotkey()
                }
            }
            .store(in: &cancellables)
    }

    private func bindBackdropSynchronization() {
        appState.$appearancePreferences
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncNotchBackdrop() }
            .store(in: &cancellables)

        accessibilityObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncNotchBackdrop()
            }
        }
    }

    private func currentResolvedSystemScheme() -> ColorScheme {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }

    func syncNotchBackdrop() {
        // Project the chrome-layout preference onto the surface. `Nook.presentation`
        // rebuilds a visible window in place when this changes, so flipping the
        // Layout picker re-places the chrome immediately.
        nook.presentation = appState.appearancePreferences.presentation

        let scheme = appState.appearancePreferences.effectiveColorScheme(systemScheme: currentResolvedSystemScheme())
        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        // Pin the window appearance first: the backdrop's visual-effect material resolves
        // against it, so a forced light/dark theme needs both to agree.
        nook.chromeAppearance = appState.appearancePreferences.chromeAppearanceOverride
        nook.backdropConfiguration = NookBackdropMapping.notchBackdrop(
            preferences: appState.appearancePreferences,
            effectiveColorScheme: scheme,
            reduceTransparency: reduceTransparency
        )
    }

    /// Mirrors the surface's live ``NookState`` onto `appState.isNookVisible`. This is the
    /// single source of truth for "is the nook expanded" — it catches hover- and
    /// drag-driven transitions, which coordinator-initiated show/hide cannot.
    private func bindSurfaceVisibility() {
        nook.$state
            .map { $0 == .expanded }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                self?.appState.isNookVisible = expanded
            }
            .store(in: &cancellables)
    }

    private func bindNookDragSession() {
        nook.$isDragInFlight
            .receive(on: RunLoop.main)
            .sink { [weak self] inFlight in
                self?.appState.isDragInFlight = inFlight
            }
            .store(in: &cancellables)

        // Route file drops through the host's configured handler (e.g. the
        // NookComponents file shelf). Absent one, drops are rejected.
        nook.onFileDrop = configuration.onFileDrop ?? { _ in false }
    }

    // MARK: - Nook lifecycle

    public func toggleNook() {
        appState.resetTransientStatus()
        enqueueLifecycle { [weak self] in
            guard let self else { return }
            // Decide off the surface's live state *at execution time*, not the mirror
            // and not when `toggleNook()` was called — a hover-expanded nook must
            // toggle closed even though no coordinator call opened it, and deciding
            // before the serial chain reaches us would race other queued transitions.
            if self.nook.state == .expanded {
                await self.nook.compact()
            } else {
                self.nook.staysExpandedOnHoverExit = self.appState.keepNookOpen
                await self.nook.expand()
            }
        }
    }

    public func showNook() {
        appState.resetTransientStatus()
        enqueueLifecycle { [weak self] in
            guard let self else { return }
            self.nook.staysExpandedOnHoverExit = self.appState.keepNookOpen
            await self.nook.expand()
        }
    }

    public func showHome() {
        appState.showHome()
        showNook()
    }

    /// Shows the Settings screen. When the host disabled Settings
    /// (``NookConfiguration/showsSettings`` is `false`) there is no Settings UI, so this
    /// falls back to showing the home surface and `viewMode` stays `.home`.
    public func showSettings() {
        guard configuration.showsSettings else {
            showNook()
            return
        }
        appState.showSettings()
        showNook()
    }

    public func hideNook() {
        enqueueLifecycle { [weak self] in
            await self?.nook.compact()
        }
    }

    public func toggleKeepNookOpen() {
        appState.keepNookOpen.toggle()
        nook.staysExpandedOnHoverExit = appState.keepNookOpen
    }

    /// Pin the nook open while a transient interaction (sheet, modal) is presented.
    /// macOS sheets surface in a new window above the notch, which moves the pointer outside
    /// the notch's hover region and causes auto-compact. Calling this with `true` suspends
    /// auto-compact; `false` restores the user's `keepNookOpen` preference.
    public func setStaysExpandedOverride(_ active: Bool) {
        if active {
            nook.staysExpandedOnHoverExit = true
        } else {
            nook.staysExpandedOnHoverExit = appState.keepNookOpen
        }
    }

    // MARK: - Reset

    /// Restores appearance prefs, the global hotkey, keep-open, and expand behavior to
    /// their defaults. The `$hotkey` binding re-registers the shortcut automatically.
    public func resetAllSettingsToDefaults() {
        // `.default` appearance preferences already carry `keepNookOpen == false`.
        appState.appearancePreferences = .default
        NookAppearanceStore.save(.default)
        appState.replaceHotkey(.default)
        appState.replaceDisplayPreference(.default)
        nook.staysExpandedOnHoverExit = false
        syncNotchBackdrop()
    }
}

// MARK: - NookSurfacePresenting

extension AppCoordinator: NookSurfacePresenting {
    /// The user owns the surface while they're hovering it or while they opened it
    /// themselves; a transient presenter pauses in either case.
    public var isUserEngaged: Bool {
        appState.isNookVisible || nook.isHovering
    }

    public var userEngagementChanges: AnyPublisher<Bool, Never> {
        appState.$isNookVisible
            .combineLatest(nook.$isHovering)
            .map { $0 || $1 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /// Grants or denies the claim through the ``SurfaceArbiter``.
    public func beginTransientPresentation(_ claim: NookSurfaceClaim) async -> NookSurfaceToken? {
        await arbiter.begin(claim)
    }

    /// Releases the claim through the ``SurfaceArbiter``.
    public func endTransientPresentation(_ token: NookSurfaceToken) async {
        await arbiter.end(token)
    }
}
