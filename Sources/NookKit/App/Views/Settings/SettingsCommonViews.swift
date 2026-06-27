// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Common chrome shared across settings groupings: section label and the shortcut key cap.
/// Local to the settings layer so the picker model isn't leaked into preferences storage.
struct ShortcutKeySquircle: View {
    let symbol: String

    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics

    var body: some View {
        Text(symbol)
            .font(typography.settingsRowTitle)
            .foregroundStyle(theme.primaryLabel.opacity(metrics.shortcutKeyCapLabelOpacity))
            .frame(minWidth: metrics.shortcutKeyCapMinWidth, minHeight: metrics.shortcutKeyCapMinHeight)
            .background(
                theme.subtleFill.opacity(metrics.shortcutKeyCapFillOpacity),
                in: RoundedRectangle(cornerRadius: metrics.shortcutKeyCapCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.shortcutKeyCapCornerRadius, style: .continuous)
                    .stroke(
                        theme.subtleStroke.opacity(metrics.shortcutKeyCapStrokeOpacity),
                        lineWidth: metrics.shortcutKeyCapStrokeWidth
                    )
            )
    }
}

public struct SettingsSectionLabel: View {
    let title: String

    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .font(typography.settingsSectionLabel)
            .foregroundStyle(theme.quaternaryLabel)
            .tracking(metrics.settingsSectionLabelTracking)
    }
}
