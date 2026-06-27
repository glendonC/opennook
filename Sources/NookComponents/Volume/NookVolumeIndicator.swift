// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookKit
import SwiftUI

/// A persistent compact-slot glyph reflecting the system output volume.
///
/// Register it as `compactLeading` or `compactTrailing` content so the current volume
/// is glanceable while the nook is collapsed:
///
/// ```swift
/// let volume = SystemVolumeObserver()
/// configuration.setCompactTrailing { NookVolumeIndicator(observer: volume) }
/// ```
///
/// It is *ambient* - it shows the level, it does not intercept or replace Apple's
/// volume HUD. Reads `\.nookResolvedTheme` from the environment for its tint.
public struct NookVolumeIndicator: View {
    @ObservedObject private var observer: SystemVolumeObserver
    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics

    public init(observer: SystemVolumeObserver) {
        self.observer = observer
    }

    public var body: some View {
        Image(systemName: Self.symbolName(volume: observer.volume, isMuted: observer.isMuted))
            .font(typography.volumeGlyph)
            .foregroundStyle(theme.primaryLabel.opacity(metrics.volumeGlyphOpacity))
            .frame(width: metrics.compactSlotSize, height: metrics.compactSlotSize)
            .accessibilityLabel(
                observer.isMuted
                    ? "Volume muted"
                    : "Volume \(Int((observer.volume * 100).rounded())) percent"
            )
    }

    /// Maps a volume level and mute state to the speaker SF Symbol that represents it.
    /// Pure and `public` so the mapping is unit-testable without a live audio device.
    public static func symbolName(volume: Double, isMuted: Bool) -> String {
        if isMuted { return "speaker.slash.fill" }
        switch volume {
            case ..<0.01: return "speaker.fill"
            case ..<0.34: return "speaker.wave.1.fill"
            case ..<0.67: return "speaker.wave.2.fill"
            default: return "speaker.wave.3.fill"
        }
    }
}
