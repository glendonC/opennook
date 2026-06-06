// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Transient status surfaced directly under the top bar.
///
/// Reads ``AppState/status`` — a short-lived message + severity cleared on every
/// show/toggle via ``AppState/resetTransientStatus()``. The severity selects the glyph.
struct NookTransientStatusBanner: View {
    @ObservedObject var appState: AppState
    let theme: NookResolvedTheme

    @Environment(\.nookChromeLabels) private var labels

    var body: some View {
        if let status = appState.status {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: status.severity.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .padding(.top, 1)

                Text(status.message)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.primaryLabel.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button {
                    appState.status = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.tertiaryLabel)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(labels.dismissHelp)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.subtleFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.subtleStroke.opacity(0.65), lineWidth: 0.5)
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
