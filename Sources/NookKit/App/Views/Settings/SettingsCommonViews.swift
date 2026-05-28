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

    var body: some View {
        Text(symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(theme.primaryLabel.opacity(0.92))
            .frame(minWidth: 24, minHeight: 22)
            .background(theme.subtleFill.opacity(0.55), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(theme.subtleStroke.opacity(0.35), lineWidth: 1)
            )
    }
}

public struct SettingsSectionLabel: View {
    let title: String

    @Environment(\.nookResolvedTheme) private var theme

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(theme.quaternaryLabel)
            .tracking(0.42)
    }
}
