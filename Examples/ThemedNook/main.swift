// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

// ThemedNook — a host-supplied theme plus lifecycle hooks.
//
// Shows `NookConfiguration.theme` (a custom `NookResolvedTheme` paints the chrome
// labels) and the `onExpand` / `onCompact` callbacks. Run with `swift run ThemedNook`
// and watch the console as you toggle the nook with ⌥⌘;.

import NookApp
import SwiftUI

/// A host-built palette. `NookResolvedTheme`'s public initializer accepts any colors;
/// the framework recommends explicit values (not system-adaptive ones) — see the
/// `NookResolvedTheme` type docs for why.
enum SunsetTheme {
    @MainActor
    static func resolve(_ appState: AppState) -> NookResolvedTheme {
        NookResolvedTheme(
            primaryLabel: Color(red: 1.0, green: 0.93, blue: 0.86),
            secondaryLabel: Color(red: 1.0, green: 0.78, blue: 0.62).opacity(0.85),
            tertiaryLabel: Color(red: 1.0, green: 0.66, blue: 0.50).opacity(0.70),
            quaternaryLabel: Color(red: 1.0, green: 0.62, blue: 0.46).opacity(0.50),
            subtleFill: Color.white.opacity(0.08),
            subtleStroke: Color.white.opacity(0.16),
            headerInactiveIcon: Color(red: 1.0, green: 0.70, blue: 0.55).opacity(0.55),
            // `accent` tints the chrome's interactive controls (lock, gear, focus rings)
            // instead of the system blue; `fontDesign` restyles the chrome's typography.
            accent: Color(red: 1.0, green: 0.55, blue: 0.30),
            fontDesign: .rounded
        )
    }
}

struct ThemedHomeView: View {
    @Environment(\.nookResolvedTheme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(theme.secondaryLabel)
            Text("Themed Nook")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.primaryLabel)
            Text("A host-supplied NookResolvedTheme paints the chrome labels.")
                .font(.system(size: 11))
                .foregroundStyle(theme.tertiaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}

var configuration = NookConfiguration()
configuration.setHome { ThemedHomeView() }
configuration.theme = { SunsetTheme.resolve($0) }
configuration.onExpand = { print("[ThemedNook] nook expanded") }
configuration.onCompact = { print("[ThemedNook] nook compacted") }
NookApp.main(configuration)
