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

    /// Host-supplied registration: home/compact content, theme, lifecycle hooks.
    public let configuration: NookConfiguration

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

    lazy var nook: Nook<AnyView, AnyView, AnyView> = {
        let nook = Nook<AnyView, AnyView, AnyView>(
            hoverBehavior: [],
            style: NookStyle(
                topCornerRadius: NookAppearance.expandedTopCornerRadius,
                bottomCornerRadius: NookAppearance.expandedBottomCornerRadius
            ),
            expanded: {
                AnyView(NookExpandedView(
                    appState: self.appState,
                    services: self.services,
                    toggleKeepOpen: { [weak self] in self?.toggleKeepNookOpen() },
                    hide: { [weak self] in self?.hideNook() },
                    resetAllSettings: { [weak self] in self?.resetAllSettingsToDefaults() },
                    theme: self.configuration.theme,
                    home: self.configuration.home,
                    topBarLeadingTitle: self.configuration.topBarLeadingTitle,
                    topBarLeadingIcon: self.configuration.topBarLeadingIcon,
                    showsTopBar: self.configuration.showsTopBar,
                    showsSettings: self.configuration.showsSettings
                ))
            },
            compactLeading: {
                AnyView(NookCompactHost(
                    appState: self.appState,
                    theme: self.configuration.theme,
                    content: self.configuration.compactLeading
                ))
            },
            compactTrailing: {
                AnyView(NookCompactHost(
                    appState: self.appState,
                    theme: self.configuration.theme,
                    content: self.configuration.compactTrailing
                ))
            }
        )
        // Project the host's lifecycle callbacks onto the surface. The hooks fire on the
        // surface's own state transitions, so hover- and drag-driven changes reach the
        // host too — not just coordinator-initiated show/hide.
        nook.onExpand = self.configuration.onExpand
        nook.onCompact = self.configuration.onCompact
        nook.onHide = self.configuration.onHide
        return nook
    }()

    public init(
        appState: AppState = AppState(),
        services: AppServices = AppServices(),
        hotkeyController: HotkeyController = HotkeyController(),
        configuration: NookConfiguration = NookConfiguration()
    ) {
        self.appState = appState
        self.services = services
        self.hotkeyController = hotkeyController
        self.configuration = configuration

        bindBackdropSynchronization()
    }

    deinit {
        if let accessibilityObserver {
            NotificationCenter.default.removeObserver(accessibilityObserver)
        }
    }

    public func start() {
        NSApp.setActivationPolicy(.accessory)

        syncNotchBackdrop()
        configureNotchAnimations()
        configureDisplayTargeting()

        registerGlobalHotkey()
        bindHotkeyRegistration()
        bindNookDragSession()

        // Cold-launch greeting: compact the chrome, then fire a one-shot shimmer along the
        // perimeter so the user sees the app is awake. Awaiting `compact()` first puts the
        // nook into a visible state so the event fires immediately instead of queuing.
        Task { @MainActor in
            await nook.compact(on: resolveScreen())
            nook.playFeedback(.shimmer, duration: 1.1)
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
                Task { @MainActor in
                    // Re-place whichever way the chrome is currently showing. A hidden
                    // nook needs nothing — its next expand/compact rebuilds on the new
                    // screen via `screenProvider`.
                    if self.appState.isNookVisible {
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
            appState.errorMessage = "Could not register global hotkey (status \(status))."
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
        if appState.isNookVisible {
            hideNook()
        } else {
            showNook()
        }
    }

    public func showNook() {
        appState.resetTransientStatus()
        appState.isNookVisible = true
        Task {
            nook.staysExpandedOnHoverExit = appState.keepNookOpen
            await nook.expand()
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
        appState.isNookVisible = false
        Task {
            await nook.compact()
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
        appState.keepNookOpen = false
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

    /// Snapshots the current state and expands the chrome. A second call while a
    /// transient presentation is already active is a no-op (the snapshot is kept).
    public func beginTransientPresentation() async {
        guard transientRestoreState == nil else { return }
        transientRestoreState = nook.state
        await nook.expand()
    }

    /// Restores the snapshotted state — unless the user engaged the surface during the
    /// presentation, in which case their state is left as-is.
    public func endTransientPresentation() async {
        guard let restore = transientRestoreState else { return }
        transientRestoreState = nil
        guard !isUserEngaged else { return }
        switch restore {
        case .compact: await nook.compact()
        case .hidden: await nook.hide()
        case .expanded: break
        }
    }
}
