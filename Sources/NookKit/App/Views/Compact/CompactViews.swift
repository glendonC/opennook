// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Default compact slot to the **left** of the notch when the nook is collapsed. The
/// shimmer peripheral cue lives in `NookSurface.NookFeedbackOverlay`; this view just
/// renders the static icon flanking the cutout.
///
/// This is the default `compactLeading` content installed by `NookConfiguration`. Host
/// apps register their own via ``NookConfiguration/setCompactLeading(_:)``.
public struct NookCompactLeadingView: View {
    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics

    public init() {}

    public var body: some View {
        Image(systemName: "house")
            .font(typography.compactLeadingGlyph)
            .foregroundStyle(theme.primaryLabel.opacity(metrics.compactLeadingGlyphOpacity))
            .frame(width: metrics.compactSlotSize, height: metrics.compactSlotSize)
    }
}

/// Default compact slot to the **right** of the notch.
public struct NookCompactTrailingView: View {
    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeMetrics) private var metrics

    public init() {}

    public var body: some View {
        NookMarkView(
            size: metrics.compactTrailingMarkSize,
            strokeWidth: metrics.compactTrailingMarkStrokeWidth,
            color: theme.primaryLabel.opacity(metrics.compactTrailingMarkOpacity)
        )
        .frame(width: metrics.compactSlotSize, height: metrics.compactSlotSize)
    }
}

/// Wraps host-registered compact content so it gets the same `\.nookResolvedTheme`
/// environment value the expanded surface injects.
///
/// `NookSurface` renders the compact slots directly, with no environment of its own, so
/// the coordinator wraps each registered compact closure in one of these. Observing
/// `AppState` keeps the resolved theme current when appearance preferences change.
struct NookCompactHost<Content: View>: View {
    @ObservedObject var appState: AppState
    let theme: (AppState) -> NookResolvedTheme
    let content: () -> Content

    var body: some View {
        let resolved = theme(appState)
        return content()
            .environment(\.nookResolvedTheme, resolved)
            .fontDesign(resolved.fontDesign)
            // Match the expanded surface: host-registered compact content gets `AppState`
            // as an `@EnvironmentObject` so it can observe chrome state directly.
            .environmentObject(appState)
    }
}
