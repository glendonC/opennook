// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookKit
import SwiftUI

/// A home-view wrapper that shows the activity currently being presented by a
/// ``NookActivityQueue``, falling back to the host's own content when the queue is idle.
///
/// Register it as the home view so queued activities can take over the expanded surface:
///
/// ```swift
/// configuration.setHome {
///     NookActivityHost(queue: queue) { MyNormalHomeView() }
/// }
/// ```
public struct NookActivityHost<Content: View>: View {
    @ObservedObject private var queue: NookActivityQueue
    private let content: () -> Content

    public init(queue: NookActivityQueue, @ViewBuilder content: @escaping () -> Content) {
        self.queue = queue
        self.content = content
    }

    public var body: some View {
        ZStack {
            if let activity = queue.current {
                NookActivityCard(activity: activity)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                content()
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: queue.current?.id)
    }
}

/// The default activity card - icon, title, subtitle. Reads `\.nookResolvedTheme` from
/// the environment so it tracks the configured chrome palette.
public struct NookActivityCard: View {
    private let activity: NookActivity
    @Environment(\.nookResolvedTheme) private var theme

    public init(activity: NookActivity) {
        self.activity = activity
    }

    public var body: some View {
        HStack(spacing: 12) {
            if let systemImage = activity.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(activity.tint)
                    .frame(width: 30)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.primaryLabel)
                if let subtitle = activity.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.secondaryLabel)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
    }
}
