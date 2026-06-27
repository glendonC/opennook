// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Host-tunable point values for the framework chrome - the element sizes, corner radii,
/// inter-element spacing, and the opacity multipliers layered on the resolved palette that
/// were previously baked into the chrome views. Defaults reproduce today's layout exactly.
///
/// Colors come from ``NookResolvedTheme`` and fonts from ``NookChromeTypography``; this
/// type covers the dimensional and emphasis constants that sit between them. To restyle a
/// single value, copy ``default`` and set the field - every property is a `public var`:
///
/// ```swift
/// var metrics = NookChromeMetrics.default
/// metrics.headerIconCornerRadius = 10
/// configuration.metrics = metrics
/// ```
///
/// Set via ``NookConfiguration/metrics``. The values reach the expanded surface, the top
/// bar, the status banner, and the compact slots through the chrome environment
/// (``EnvironmentValues/nookChromeMetrics``).
public struct NookChromeMetrics: Sendable, Equatable {

    // MARK: - Expanded surface

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

    /// Vertical gap between the top bar, the status banner, and the home/settings surface
    /// in the expanded column. Default `8`.
    public var expandedColumnSpacing: CGFloat

    // MARK: - Top bar

    /// Fixed height of the top bar's icon row. Default `24`.
    public var topBarHeight: CGFloat

    /// Horizontal gap between the top bar's leading content, the flexible spacer, and the
    /// trailing cluster. Default `8`.
    public var topBarItemSpacing: CGFloat

    /// Gap between the leading brand mark / icon and its title (and the same gap inside the
    /// in-surface module switcher's label). Default `6`.
    public var leadingClusterSpacing: CGFloat

    /// Gap between the trailing host items, the keep-open lock, and the gear. Tighter than
    /// the leading cluster. Default `4`.
    public var trailingClusterSpacing: CGFloat

    /// Maximum width of the top bar's module-breadcrumb label before it fades - capped to
    /// the leading pre-notch region so it doesn't split across the notch. Default `140`.
    public var breadcrumbMaxWidth: CGFloat

    // MARK: - Header icons (lock / gear / home glyphs)

    /// Square size of each header icon's hit and visual frame. Default `24`.
    public var headerIconSize: CGFloat

    /// Corner radius of a header icon's hover background fill and outline. Default `7`.
    public var headerIconCornerRadius: CGFloat

    /// Line width of a header icon's hover outline. Default `1`.
    public var headerIconStrokeWidth: CGFloat

    /// Opacity multiplier on the resolved primary label for a hovered header icon's glyph.
    /// Default `0.92`.
    public var headerIconHoverLabelOpacity: CGFloat

    // MARK: - Leading brand mark

    /// Point size and bounding frame of the top bar's leading-cluster brand mark glyph
    /// (used when no host `leadingIcon` is set). Default `11`.
    public var brandMarkSize: CGFloat

    /// Stroke width of the leading-cluster brand mark glyph. Default `1.1`.
    public var brandMarkStrokeWidth: CGFloat

    /// Opacity multiplier on the resolved secondary label for the leading brand mark.
    /// Default `0.92`.
    public var brandMarkOpacity: CGFloat

    // MARK: - Compact pill

    /// Square size of each compact pill slot (the glyphs flanking the notch). Default `24`.
    public var compactSlotSize: CGFloat

    /// Opacity multiplier on the resolved primary label for the default compact leading
    /// glyph. Default `0.88`.
    public var compactLeadingGlyphOpacity: CGFloat

    /// Point size of the default compact trailing mark glyph. Distinct from
    /// ``compactSlotSize`` (the slot frame around it). Default `11`.
    public var compactTrailingMarkSize: CGFloat

    /// Stroke width of the default compact trailing mark glyph. Default `1.1`.
    public var compactTrailingMarkStrokeWidth: CGFloat

    /// Opacity multiplier on the resolved primary label for the default compact trailing
    /// mark. Default `0.82`.
    public var compactTrailingMarkOpacity: CGFloat

    // MARK: - Status banner

    /// Item spacing inside the status banner row (severity glyph / message / dismiss).
    /// Default `8`.
    public var bannerRowSpacing: CGFloat

    /// Corner radius of the status banner's background fill and outline. Default `10`.
    public var bannerCornerRadius: CGFloat

    /// Horizontal padding inside the status banner. Default `10`.
    public var bannerContentHorizontalPadding: CGFloat

    /// Vertical padding inside the status banner. Default `7`.
    public var bannerContentVerticalPadding: CGFloat

    /// Top nudge aligning the banner severity glyph with the first line of message text.
    /// Default `1`.
    public var bannerSeverityGlyphTopInset: CGFloat

    /// Square size of the banner's dismiss button hit frame. Default `18`.
    public var bannerDismissButtonSize: CGFloat

    /// Opacity multiplier on the resolved primary label for the banner message. Default `0.92`.
    public var bannerMessageLabelOpacity: CGFloat

    /// Opacity multiplier on the resolved subtle stroke for the banner outline. Default `0.65`.
    public var bannerStrokeOpacity: CGFloat

    /// Line width of the banner outline. Default `0.5`.
    public var bannerStrokeWidth: CGFloat

    public init(
        edgePadding: CGFloat = NookLayout.edgePadding,
        expandedColumnSpacing: CGFloat = 8,
        topBarHeight: CGFloat = NookLayout.topBarHeight,
        topBarItemSpacing: CGFloat = 8,
        leadingClusterSpacing: CGFloat = 6,
        trailingClusterSpacing: CGFloat = 4,
        breadcrumbMaxWidth: CGFloat = NookLayout.breadcrumbMaxWidth,
        headerIconSize: CGFloat = 24,
        headerIconCornerRadius: CGFloat = 7,
        headerIconStrokeWidth: CGFloat = 1,
        headerIconHoverLabelOpacity: CGFloat = 0.92,
        brandMarkSize: CGFloat = 11,
        brandMarkStrokeWidth: CGFloat = 1.1,
        brandMarkOpacity: CGFloat = 0.92,
        compactSlotSize: CGFloat = NookLayout.compactSlotSize,
        compactLeadingGlyphOpacity: CGFloat = 0.88,
        compactTrailingMarkSize: CGFloat = 11,
        compactTrailingMarkStrokeWidth: CGFloat = 1.1,
        compactTrailingMarkOpacity: CGFloat = 0.82,
        bannerRowSpacing: CGFloat = 8,
        bannerCornerRadius: CGFloat = 10,
        bannerContentHorizontalPadding: CGFloat = 10,
        bannerContentVerticalPadding: CGFloat = 7,
        bannerSeverityGlyphTopInset: CGFloat = 1,
        bannerDismissButtonSize: CGFloat = 18,
        bannerMessageLabelOpacity: CGFloat = 0.92,
        bannerStrokeOpacity: CGFloat = 0.65,
        bannerStrokeWidth: CGFloat = 0.5
    ) {
        self.edgePadding = edgePadding
        self.expandedColumnSpacing = expandedColumnSpacing
        self.topBarHeight = topBarHeight
        self.topBarItemSpacing = topBarItemSpacing
        self.leadingClusterSpacing = leadingClusterSpacing
        self.trailingClusterSpacing = trailingClusterSpacing
        self.breadcrumbMaxWidth = breadcrumbMaxWidth
        self.headerIconSize = headerIconSize
        self.headerIconCornerRadius = headerIconCornerRadius
        self.headerIconStrokeWidth = headerIconStrokeWidth
        self.headerIconHoverLabelOpacity = headerIconHoverLabelOpacity
        self.brandMarkSize = brandMarkSize
        self.brandMarkStrokeWidth = brandMarkStrokeWidth
        self.brandMarkOpacity = brandMarkOpacity
        self.compactSlotSize = compactSlotSize
        self.compactLeadingGlyphOpacity = compactLeadingGlyphOpacity
        self.compactTrailingMarkSize = compactTrailingMarkSize
        self.compactTrailingMarkStrokeWidth = compactTrailingMarkStrokeWidth
        self.compactTrailingMarkOpacity = compactTrailingMarkOpacity
        self.bannerRowSpacing = bannerRowSpacing
        self.bannerCornerRadius = bannerCornerRadius
        self.bannerContentHorizontalPadding = bannerContentHorizontalPadding
        self.bannerContentVerticalPadding = bannerContentVerticalPadding
        self.bannerSeverityGlyphTopInset = bannerSeverityGlyphTopInset
        self.bannerDismissButtonSize = bannerDismissButtonSize
        self.bannerMessageLabelOpacity = bannerMessageLabelOpacity
        self.bannerStrokeOpacity = bannerStrokeOpacity
        self.bannerStrokeWidth = bannerStrokeWidth
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
