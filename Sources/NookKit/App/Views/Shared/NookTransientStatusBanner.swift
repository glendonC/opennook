// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Transient status surfaced directly under the top bar.
///
/// Reads ``AppState/status`` - a short-lived message + severity cleared on every
/// show/toggle via ``AppState/resetTransientStatus()``. The severity selects the glyph.
struct NookTransientStatusBanner: View {
    @ObservedObject var appState: AppState
    let theme: NookResolvedTheme

    @Environment(\.nookChromeLabels) private var labels
    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics

    var body: some View {
        if let status = appState.status {
            HStack(alignment: .top, spacing: metrics.bannerRowSpacing) {
                Image(systemName: status.severity.systemImage)
                    .font(typography.bannerSeverityGlyph)
                    .foregroundStyle(theme.accent)
                    .padding(.top, metrics.bannerSeverityGlyphTopInset)

                Text(status.message)
                    .font(typography.bannerMessage)
                    .foregroundStyle(theme.primaryLabel.opacity(metrics.bannerMessageLabelOpacity))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button {
                    appState.status = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(typography.bannerDismissGlyph)
                        .foregroundStyle(theme.tertiaryLabel)
                        .frame(width: metrics.bannerDismissButtonSize, height: metrics.bannerDismissButtonSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(labels.dismissHelp)
            }
            .padding(.horizontal, metrics.bannerContentHorizontalPadding)
            .padding(.vertical, metrics.bannerContentVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: metrics.bannerCornerRadius, style: .continuous)
                    .fill(theme.subtleFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.bannerCornerRadius, style: .continuous)
                    .stroke(
                        theme.subtleStroke.opacity(metrics.bannerStrokeOpacity),
                        lineWidth: metrics.bannerStrokeWidth
                    )
            )
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                )
            )
        }
    }
}
