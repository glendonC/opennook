// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Combine
import Foundation

/// Which framework chrome screen is filling the expanded surface — the active module's
/// home view, or the framework Settings panel.
///
/// `NookExpandedView` routes off this. When the host disabled Settings
/// (``NookTopBarConfiguration/showsSettings``), ``settings`` is unreachable and
/// ``AppCoordinator/showSettings()`` falls back to ``home``.
public enum NookViewMode: Equatable, Sendable {
    case home
    case settings
}

/// A durable description of a global hotkey that failed to register. Carries the
/// human-facing shortcut name and the combination that was rejected, so Settings can
/// tell the user *which* shortcut is unavailable rather than a single shared string.
public struct HotkeyRegistrationFailure: Equatable, Sendable {
    /// Human-readable name of the shortcut, e.g. `"Show Nook"` or a module's display name.
    public let shortcutName: String
    /// The key combination that failed to register, e.g. `"⌥⌘;"`.
    public let combination: String

    public init(shortcutName: String, combination: String) {
        self.shortcutName = shortcutName
        self.combination = combination
    }

    /// A ready-to-show one-line warning for the Settings UI.
    public var message: String {
        "\(combination) is unavailable — another app may be using it."
    }
}

/// Mutable, observable state shared between the coordinator and views.
/// Holds chrome-level concerns (view mode, appearance, keep-open, visibility) — product
/// data lives in whatever model layer a downstream fork adds on top.
///
/// **Swap point for product state.** A downstream fork that needs cross-view product
/// state has two clean options: add `@Published` properties alongside the chrome ones
/// here (simplest), or hold product state in its own type reachable via ``AppServices``
/// (better separation, scales across multi-module hosts).
public final class AppState: ObservableObject {
    /// Which framework chrome screen the expanded surface is showing. Written via
    /// ``showHome()``/``showSettings()``; observed by `NookExpandedView`.
    @Published public private(set) var viewMode: NookViewMode = .home

    /// Persisted appearance personalization (palette, surface style, presentation,
    /// haptics, keep-open). Assigning replaces the whole value — use
    /// ``replaceAppearancePreferences(_:)`` to also persist the change.
    @Published public var appearancePreferences = NookAppearancePreferences.default

    /// The user-configured global show/hide shortcut. Persisted to `UserDefaults` only
    /// when written through ``replaceHotkey(_:)``.
    @Published public var hotkey = NookHotkey.default

    /// Which display the Nook chrome appears on. The coordinator projects this onto
    /// the surface (`Nook.screenProvider`) and re-places the chrome when it changes.
    @Published public var displayPreference = NookDisplayPreference.default

    /// When on, the expanded nook stays open past hover-exit. Backed by
    /// ``NookAppearancePreferences/keepNookOpen`` so it persists across launches;
    /// reading or writing it goes through `appearancePreferences`.
    public var keepNookOpen: Bool {
        get { appearancePreferences.keepNookOpen }
        set {
            guard newValue != appearancePreferences.keepNookOpen else { return }
            var preferences = appearancePreferences
            preferences.keepNookOpen = newValue
            replaceAppearancePreferences(preferences)
        }
    }

    /// `true` while the nook surface is expanded. This is a read-only mirror of the
    /// surface's own ``NookState`` — the coordinator binds it to `Nook.$state`, so it
    /// stays accurate for hover- and drag-driven transitions too, not just
    /// coordinator-initiated show/hide. Drive visibility through ``AppCoordinator``,
    /// never by writing this.
    ///
    /// This is purely a view-model mirror. It is NOT consulted by the surface arbiter
    /// to decide "is the user engaged" — see ``AppCoordinator/isUserEngaged``, which
    /// reads an explicit user-intent flag to avoid mistaking the arbiter's own expand
    /// for user engagement.
    @Published public internal(set) var isNookVisible = false

    /// Transient status channel — a short-lived ``NookStatus`` (message + severity) tied
    /// to a single nook session. Cleared by ``resetTransientStatus()`` on every
    /// show/toggle. Hotkey-registration failures must NOT live here: they outlive a nook
    /// session and need to stay visible until the registration is fixed. Those use
    /// ``hotkeyRegistrationFailures`` instead.
    @Published public var status: NookStatus?

    /// Back-compatible string view of ``status`` — reading returns the current message,
    /// writing posts an `.error`-severity status (and `nil` clears it). Prefer
    /// ``showStatus(_:severity:)`` to post non-error severities.
    public var errorMessage: String? {
        get { status?.message }
        set { status = newValue.map { NookStatus(message: $0, severity: .error) } }
    }

    /// Posts a transient status with an explicit severity (defaults to `.error`). Shown
    /// in the top-bar banner until dismissed or cleared by the next show/toggle.
    public func showStatus(_ message: String, severity: NookStatusSeverity = .error) {
        status = NookStatus(message: message, severity: severity)
    }

    /// Durable hotkey-registration failures, keyed by ``HotkeyController`` registration id
    /// (`"toggle"`, `"cycle"`, `"module.<id>"`). Each value is a human-readable failure
    /// for that specific shortcut. Unlike ``errorMessage`` this is NOT cleared by
    /// ``resetTransientStatus()``: a failed registration stays surfaced until that
    /// registration actually succeeds (or the offending hotkey is changed), at which
    /// point the coordinator clears that id's entry. Each entry reflects the CURRENT
    /// outcome of its registration — not a last-writer-wins shared string.
    @Published public internal(set) var hotkeyRegistrationFailures: [String: HotkeyRegistrationFailure] = [:]

    /// Records the outcome of one hotkey registration attempt: `failure` non-nil keeps
    /// the entry, `nil` clears it. Called by the coordinator after every (re-)register.
    func recordHotkeyRegistration(id: String, failure: HotkeyRegistrationFailure?) {
        if let failure {
            hotkeyRegistrationFailures[id] = failure
        } else {
            hotkeyRegistrationFailures.removeValue(forKey: id)
        }
    }

    /// `true` while the user is recording a new global hotkey in Settings. The coordinator
    /// watches this and suspends the live hotkey registration so the old shortcut can't
    /// fire mid-capture.
    @Published public var isRecordingHotkey = false

    /// Mirrors `Nook.isDragInFlight`. `true` while a system file-drag session is over the
    /// panel — kept as a hook-point for downstream consumers that want drop targets.
    @Published public var isDragInFlight: Bool = false

    /// Optional secondary label rendered in the top bar after the leading title
    /// (`[icon] Module  ›  Breadcrumb`). Modules use this to surface the current
    /// drill-down context — a selected deck, an open document, a chosen profile
    /// — so the chrome reflects what the user is actually looking at, instead of
    /// the module's static name. Set to `nil` to clear.
    ///
    /// The chrome treats this as a soft state hint: it doesn't affect ``viewMode``
    /// or the back-to-home affordance. A module that wants the breadcrumb to be
    /// clickable (e.g. "click to pop back one level") owns that interaction
    /// inside its own surface — the chrome only renders the text.
    @Published public var moduleBreadcrumb: String?

    /// Loads the persisted appearance, hotkey, and display preferences from
    /// `UserDefaults`. Any missing or unreadable entry falls back to its `.default`.
    public convenience init() {
        self.init(preferenceDefaults: .default)
    }

    /// Loads the persisted appearance, hotkey, and display preferences from
    /// `UserDefaults`, falling back to the host's launch *seed* (rather than the
    /// framework `.default`) for any entry that has never been persisted. See
    /// ``NookPreferenceDefaults`` for the seed semantics — the seed is never written
    /// here, so a persisted user choice always wins.
    public init(preferenceDefaults: NookPreferenceDefaults) {
        appearancePreferences = NookAppearanceStore.load(default: preferenceDefaults.appearance)
        hotkey = NookHotkeyStore.load(default: preferenceDefaults.hotkey)
        displayPreference = NookDisplayStore.load(default: preferenceDefaults.display)
    }

    /// Replaces ``appearancePreferences`` and writes the new value to `UserDefaults`. A
    /// no-op when the value is unchanged. Prefer this over assigning the property
    /// directly — direct assignment skips persistence.
    public func replaceAppearancePreferences(_ preferences: NookAppearancePreferences) {
        guard preferences != appearancePreferences else {
            return
        }
        appearancePreferences = preferences
        NookAppearanceStore.save(preferences)
    }

    /// Replaces ``hotkey`` and persists. The coordinator's hotkey-registration sink
    /// picks up the change and re-registers the global shortcut.
    public func replaceHotkey(_ hotkey: NookHotkey) {
        guard hotkey != self.hotkey else {
            return
        }
        self.hotkey = hotkey
        NookHotkeyStore.save(hotkey)
    }

    /// Replaces ``displayPreference`` and persists. The coordinator re-places the
    /// chrome on the newly chosen display.
    public func replaceDisplayPreference(_ preference: NookDisplayPreference) {
        guard preference != displayPreference else {
            return
        }
        displayPreference = preference
        NookDisplayStore.save(preference)
    }

    public var isHomeView: Bool {
        viewMode == .home
    }

    public var isSettingsView: Bool {
        viewMode == .settings
    }

    /// Switches the chrome to the home view and clears ``errorMessage``.
    public func showHome() {
        viewMode = .home
        resetTransientStatus()
    }

    /// Switches the chrome to the Settings screen and clears ``errorMessage``. The host's
    /// ``NookTopBarConfiguration/showsSettings`` flag is enforced by
    /// ``AppCoordinator/showSettings()``, not here.
    public func showSettings() {
        viewMode = .settings
        resetTransientStatus()
    }

    /// Clears the transient ``status``. Called on every show/toggle so a stale transient
    /// message can't bleed into the next session. Durable hotkey-registration failures
    /// live on ``hotkeyRegistrationFailures`` and are not cleared here.
    public func resetTransientStatus() {
        status = nil
    }
}
