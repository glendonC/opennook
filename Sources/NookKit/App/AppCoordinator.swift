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
    public let services: AppServices

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

    /// Surface state captured at `beginTransientPresentation()`, restored when the
    /// transient presentation ends. Non-`nil` only while a transient takeover is active.
    var transientRestoreState: NookState?

    /// `true` once ``start()`` has run. Guards against a double `start()` registering
    /// duplicate observers, sinks, and `onReady` callbacks.
    private var hasStarted = false

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
                    services: self.services,
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
        services: AppServices = AppServices(),
        hotkeyController: HotkeyController = HotkeyController(),
        configuration: NookConfiguration = NookConfiguration()
    ) {
        self.init(
            appState: appState,
            services: services,
            hotkeyController: hotkeyController,
            moduleHost: ModuleHost(configuration: configuration)
        )
    }

    public init(
        appState: AppState = AppState(),
        services: AppServices = AppServices(),
        hotkeyController: HotkeyController = HotkeyController(),
        moduleHost: ModuleHost
    ) {
        self.appState = appState
        self.services = services
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
        configuration.onReady?(self)
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

    /// Snapshots the current state and expands the chrome. Returns `false` — without
    /// snapshotting or expanding — when a transient presentation is already active, or
    /// when the user is engaging the surface. Runs on the serial lifecycle chain, so
    /// the engagement check happens *after* any queued user-initiated transition, not
    /// at call time.
    public func beginTransientPresentation() async -> Bool {
        var didPresent = false
        await enqueueLifecycle { [weak self] in
            guard let self, self.transientRestoreState == nil, !self.isUserEngaged else { return }
            self.transientRestoreState = self.nook.state
            await self.nook.expand()
            didPresent = true
        }.value
        return didPresent
    }

    /// Restores the snapshotted state — unless the user engaged the surface during the
    /// presentation, in which case their state is left as-is.
    public func endTransientPresentation() async {
        await enqueueLifecycle { [weak self] in
            guard let self, let restore = self.transientRestoreState else { return }
            self.transientRestoreState = nil
            guard !self.isUserEngaged else { return }
            switch restore {
            case .compact: await self.nook.compact()
            case .hidden: await self.nook.hide()
            case .expanded: break
            }
        }.value
    }
}
