// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Inline tappable row used inside a settings group ("Stay expanded", etc.).
/// Lives in `Shared` and is `public` so downstream targets can reuse the row
/// chrome without duplicating the visual idiom.
public struct SettingActionLine: View {
    let icon: String
    let title: String
    let detail: String
    let accent: Color
    let action: () -> Void

    @Environment(\.nookResolvedTheme) private var theme
    @State private var isHovering = false

    public init(
        icon: String,
        title: String,
        detail: String,
        accent: Color,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.accent = accent
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isHovering ? accent : theme.headerInactiveIcon)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(isHovering ? accent : theme.primaryLabel)

                    Text(detail)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(theme.secondaryLabel)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
