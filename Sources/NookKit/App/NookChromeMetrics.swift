// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Host-tunable layout metrics for the framework chrome - the few fixed point values
/// that were previously baked into the views as `NookLayout` constants. Defaults
/// reproduce today's layout exactly.
///
/// Set via ``NookConfiguration/metrics``. The values reach the expanded surface, the top
/// bar, and the compact slots through the chrome environment
/// (``EnvironmentValues/nookChromeMetrics``).
public struct NookChromeMetrics: Sendable, Equatable {
    /// Inset between the expanded panel edge and its content (and the basis for the
    /// re-injected safe-area insets). Default `8`.
    ///
    /// Applied by ``NookExpandedView`` around the inner VStack pinned to
    /// ``NookConfiguration/expandedWidth``. Distinct from
    /// ``NookStyle/expandedContentInsets`` (the chrome's own `.safeAreaInset` strip on
    /// ``NookView``). Host home views should not mirror this with extra horizontal
    /// padding - read ``EnvironmentValues/nookContentInsets`` instead. See
    /// `Examples/LayoutNook/main.swift`.
    public var edgePadding: CGFloat

    /// Square size of each compact pill slot (the glyphs flanking the notch). Default `24`.
    public var compactSlotSize: CGFloat

    /// Maximum width of the top bar's module-breadcrumb label before it fades - capped to
    /// the leading pre-notch region so it doesn't split across the notch. Default `140`.
    public var breadcrumbMaxWidth: CGFloat

    /// Fixed height of the top bar's icon row. Default `24`.
    public var topBarHeight: CGFloat

    public init(
        edgePadding: CGFloat = NookLayout.edgePadding,
        compactSlotSize: CGFloat = NookLayout.compactSlotSize,
        breadcrumbMaxWidth: CGFloat = NookLayout.breadcrumbMaxWidth,
        topBarHeight: CGFloat = NookLayout.topBarHeight
    ) {
        self.edgePadding = edgePadding
        self.compactSlotSize = compactSlotSize
        self.breadcrumbMaxWidth = breadcrumbMaxWidth
        self.topBarHeight = topBarHeight
    }

    /// The framework-default metrics - reproduces today's layout.
    public static let `default` = NookChromeMetrics()
}

private struct NookChromeMetricsKey: EnvironmentKey {
    static let defaultValue: NookChromeMetrics = .default
}

public extension EnvironmentValues {
    /// Host-tunable chrome layout metrics. See ``NookChromeMetrics``.
    var nookChromeMetrics: NookChromeMetrics {
        get { self[NookChromeMetricsKey.self] }
        set { self[NookChromeMetricsKey.self] = newValue }
    }
}
