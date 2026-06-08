// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

// LayoutNook — recommended expanded-width and content-inset patterns for host apps.
//
// Where ChromeNook tours chrome-customization seams and ThemedNook shows palette +
// lifecycle hooks, this example focuses on how the expanded panel's width and insets
// compose — and how a home view should read `\.nookContentInsets` instead of adding
// its own horizontal padding.
//
// Run with `swift run LayoutNook`, then press ⌥⌘; to expand.
//
// See also: site guide "Layout and content insets" (`guides/layout-and-insets`).

import NookApp
import SwiftUI

/// Recommended home layout: edge-aligned content and a full-width bottom command row
/// both read `\.nookContentInsets` — no extra `.padding(.horizontal, …)` on the root.
struct LayoutHomeView: View {
    @Environment(\.nookContentInsets) private var contentInsets
    @Environment(\.nookResolvedTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("LayoutNook")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.primaryLabel)

                Text(
                    "Horizontal gutter comes from `NookExpandedView` (contentColumn top bar). "
                        + "Host rows only need vertical `nookContentInsets` for bottom curves."
                )
                .font(.system(size: 11))
                .foregroundStyle(theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.top, 4)

            commandRow
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Bottom toolbars span the shared content column; only bottom inset clears the curve.
    private var commandRow: some View {
        HStack(spacing: 8) {
            commandChip("Send", icon: "paperplane.fill")
            commandChip("Clear", icon: "trash")
            Spacer(minLength: 0)
            Text("⌘↩")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.quaternaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, contentInsets.bottom)
        .padding(.top, 6)
    }

    private func commandChip(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(theme.primaryLabel)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(theme.subtleFill, in: Capsule())
    }
}

var configuration = NookConfiguration()
configuration.setHome { LayoutHomeView() }

// Pin a stable expanded width (Peeknook-style 600 pt). The glass panel sizes to fit;
// this only fixes the inner content column so home and Settings don't resize each other.
configuration.expandedWidth = 600

// Trim the chrome's bottom safe-area strip (default 8 → 2) so centered rows sit closer
// to the rounded bottom. Edge-aligned rows still clear the curve via `nookContentInsets`.
configuration.style = NookStyle(
    topCornerRadius: 19,
    bottomCornerRadius: 24,
    expandedContentInsets: NookEdgeInsets(top: 0, bottom: 2, leading: 8, trailing: 8)
)

// `metrics.edgePadding` (default 8) is already applied by `NookExpandedView`. Do not
// mirror it with `.padding(.horizontal, 12)` on the home root — that stacks insets and
// leaves dead space beside answer text and bottom command rows.

NookApp.main(configuration)
