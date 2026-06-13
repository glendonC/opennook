// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookSurface
import XCTest
@testable import NookKit

/// Launch-seed preference defaults: a host can ship its own out-of-box appearance /
/// hotkey / display without the user opening Settings, while any value the user has
/// already persisted always wins and the seed is never written.
///
/// `@MainActor`: `AppState` / `AppCoordinator` are main-actor isolated.
@MainActor
final class NookPreferenceDefaultsTests: XCTestCase {
    private var customDefaults: NookPreferenceDefaults {
        NookPreferenceDefaults(
            appearance: NookAppearancePreferences(
                chromePalette: .dark,
                surfaceStyle: .translucent,
                presentation: .floating,
                hapticFeedbackEnabled: true,
                keepNookOpen: true
            ),
            hotkey: NookHotkey(keyCode: 12, carbonModifiers: 256, keySymbol: "Q"),
            display: .main
        )
    }

    /// The default bag reproduces the framework exactly, and both configuration structs
    /// default to it - so an unconfigured host behaves as before.
    func testDefaultsReproduceFramework() {
        PreferenceStoreTestIsolation.withIsolatedStore {
            XCTAssertEqual(NookPreferenceDefaults.default, NookPreferenceDefaults())
            XCTAssertEqual(NookPreferenceDefaults.default.appearance, .default)
            XCTAssertEqual(NookPreferenceDefaults.default.hotkey, .default)
            XCTAssertEqual(NookPreferenceDefaults.default.display, .default)

            XCTAssertEqual(NookConfiguration().preferenceDefaults, .default)
            XCTAssertEqual(NookHostConfiguration().preferenceDefaults, .default)
        }
    }

    /// With nothing persisted, `AppState` seeds from the host defaults.
    func testAppStateSeedsFromDefaultsWhenNothingPersisted() {
        PreferenceStoreTestIsolation.withIsolatedStore {
            let appState = AppState(preferenceDefaults: customDefaults)

            XCTAssertEqual(appState.appearancePreferences, customDefaults.appearance)
            XCTAssertEqual(appState.hotkey, customDefaults.hotkey)
            XCTAssertEqual(appState.displayPreference, customDefaults.display)
        }
    }

    /// `AppState()` (and a `.default` seed) still falls back to framework defaults.
    func testAppStateWithoutSeedUsesFrameworkDefaults() {
        PreferenceStoreTestIsolation.withIsolatedStore {
            let appState = AppState()

            XCTAssertEqual(appState.appearancePreferences, .default)
            XCTAssertEqual(appState.hotkey, .default)
            XCTAssertEqual(appState.displayPreference, .default)
        }
    }

    /// A value the user has already persisted beats the host seed.
    func testPersistedValueBeatsSeed() {
        PreferenceStoreTestIsolation.withIsolatedStore {
            let persisted = NookAppearancePreferences(chromePalette: .light)
            NookAppearanceStore.save(persisted)

            let appState = AppState(preferenceDefaults: customDefaults)

            XCTAssertEqual(appState.appearancePreferences, persisted)
            XCTAssertNotEqual(appState.appearancePreferences, customDefaults.appearance)
        }
    }

    /// Seeding must not write the host defaults to `UserDefaults` - otherwise a later
    /// build couldn't revise them for users who never touched Settings.
    func testSeedIsNotPersisted() {
        PreferenceStoreTestIsolation.withIsolatedStore {
            _ = AppState(preferenceDefaults: customDefaults)

            for key in PreferenceStoreTestIsolation.storeKeys {
                XCTAssertNil(
                    NookPreferenceStorage.defaults.data(forKey: key),
                    "Seeding wrote \(key) to UserDefaults; it should stay a pure fallback."
                )
            }
        }
    }

    /// The seeded appearance reaches the surface on the first backdrop sync - the path
    /// the chrome's first paint uses - so a host's launch presentation is honored before
    /// any user interaction.
    func testSeededPresentationReachesSurface() {
        PreferenceStoreTestIsolation.withIsolatedStore {
            let seeded = AppState(
                preferenceDefaults: NookPreferenceDefaults(
                    appearance: NookAppearancePreferences(presentation: .floating)
                )
            )
            let surface = FakeNookSurface()
            let coordinator = AppCoordinator(
                appState: seeded,
                moduleHost: ModuleHost(configuration: NookConfiguration()),
                surface: surface
            )

            coordinator.syncNotchBackdrop()

            XCTAssertEqual(surface.presentation, .floating)
        }
    }
}
