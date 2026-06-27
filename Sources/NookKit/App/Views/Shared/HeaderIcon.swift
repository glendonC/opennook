// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Static header icon (no hover, no action) used by the persistent "Home" cluster.
///
/// Mirrors `HeaderIcon`'s glyph font and frame styling (``NookChromeTypography/headerIcon``
/// / ``NookChromeMetrics/headerIconSize``) so the home glyph reads at the same minimal
/// weight as the lock / gear / search icons on the right side of the topbar. The
/// deliberately muted tone (vs. `primaryLabel`) keeps it as chrome rather than competing
/// with whatever the user actually came to do.
struct StaticHeaderIcon: View {
    let systemName: String

    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics

    var body: some View {
        Image(systemName: systemName)
            .font(typography.headerIcon)
            .foregroundStyle(theme.headerInactiveIcon)
            .frame(width: metrics.headerIconSize, height: metrics.headerIconSize)
    }
}

/// Hover-and-tap glyph in the topbar (sidebar toggle, settings, search, etc.). Active state
/// is colored by `activeColor`; idle by the resolved theme.
struct HeaderIcon: View {
    let systemName: String
    let isActive: Bool
    let activeColor: Color
    let help: String
    let action: () -> Void

    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(typography.headerIcon)
                .foregroundStyle(foreground)
                .frame(width: metrics.headerIconSize, height: metrics.headerIconSize)
                .background(
                    isHovering ? theme.subtleFill : .clear,
                    in: RoundedRectangle(cornerRadius: metrics.headerIconCornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.headerIconCornerRadius, style: .continuous)
                        .stroke(isHovering ? theme.subtleStroke : .clear, lineWidth: metrics.headerIconStrokeWidth)
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { isHovering = $0 }
    }

    /// Active state wins; otherwise the glyph lifts to the emphasized primary label on
    /// hover and rests on the muted inactive tone.
    private var foreground: Color {
        if isActive { return activeColor }
        return isHovering ? theme.primaryLabel.opacity(metrics.headerIconHoverLabelOpacity) : theme.headerInactiveIcon
    }
}
