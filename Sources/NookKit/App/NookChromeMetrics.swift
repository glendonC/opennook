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

    // MARK: - Components (opt-in NookComponents add-ons)

    /// Spacing inside the file shelf's stacks (root column, drop zone, item row). Default `8`.
    public var shelfContentSpacing: CGFloat

    /// Outer vertical padding of the file shelf surface. Default `6`.
    public var shelfRootVerticalPadding: CGFloat

    /// Vertical padding that gives the empty drop zone its height. Default `28`.
    public var shelfDropZoneVerticalPadding: CGFloat

    /// Corner radius of the empty drop zone's dashed well. Default `12`.
    public var shelfDropZoneCornerRadius: CGFloat

    /// Line width of the drop zone's dashed border. Default `1`.
    public var shelfDropZoneStrokeWidth: CGFloat

    /// Spacing in the populated shelf header (count / import / clear). Default `10`.
    public var shelfHeaderSpacing: CGFloat

    /// Spacing inside a shelf item chip (icon over filename). Default `4`.
    public var shelfChipSpacing: CGFloat

    /// Fixed width of a shelf item chip. Default `72`.
    public var shelfChipWidth: CGFloat

    /// Inner padding of a shelf item chip. Default `8`.
    public var shelfChipPadding: CGFloat

    /// Corner radius of a shelf item chip. Default `10`.
    public var shelfChipCornerRadius: CGFloat

    /// Square size of a shelf item's file icon. Default `34`.
    public var shelfIconSize: CGFloat

    /// Vertical padding around the horizontal shelf row. Default `2`.
    public var shelfRowVerticalPadding: CGFloat

    /// Spacing between the activity card's icon and its text column. Default `12`.
    public var activityCardSpacing: CGFloat

    /// Fixed width reserved for the activity card's leading icon. Default `30`.
    public var activityIconWidth: CGFloat

    /// Spacing between the activity card's title and subtitle. Default `2`.
    public var activityTextSpacing: CGFloat

    /// Vertical padding of the activity card. Default `16`.
    public var activityCardVerticalPadding: CGFloat

    /// Horizontal padding of the activity card. Default `8`.
    public var activityCardHorizontalPadding: CGFloat

    /// Opacity multiplier on the resolved primary label for the ambient volume glyph.
    /// Default `0.85`.
    public var volumeGlyphOpacity: CGFloat

    // MARK: - Placeholder home

    /// Spacing between the placeholder home's mark, title, and body. Default `10`.
    public var placeholderStackSpacing: CGFloat

    /// Point size of the placeholder home's brand mark. Default `28`.
    public var placeholderMarkSize: CGFloat

    /// Stroke width of the placeholder home's brand mark. Default `2`.
    public var placeholderMarkStrokeWidth: CGFloat

    /// Outer vertical padding of the placeholder home. Default `40`.
    public var placeholderVerticalPadding: CGFloat

    // MARK: - Settings panel

    /// Spacing between top-level settings sections. Default `16`.
    public var settingsSectionSpacing: CGFloat

    /// Spacing between rows within a settings group. Default `12`.
    public var settingsGroupSpacing: CGFloat

    /// Horizontal spacing between a settings row's icon and its text. Default `10`.
    public var settingsRowSpacing: CGFloat

    /// Vertical spacing between blocks within a settings section. Default `10`.
    public var settingsBlockSpacing: CGFloat

    /// Spacing between a settings field label and its control. Default `5`.
    public var settingsFieldSpacing: CGFloat

    /// Spacing between a settings row's title and its detail. Default `2`.
    public var settingsTextSpacing: CGFloat

    /// Spacing between the About card's name and tagline. Default `3`.
    public var settingsAboutTextSpacing: CGFloat

    /// Inline spacing inside settings rows (disclosure header, accent swatches, About name).
    /// Default `6`.
    public var settingsInlineSpacing: CGFloat

    /// Bottom padding under the scrolling settings content. Default `14`.
    public var settingsContentBottomPadding: CGFloat

    /// Vertical padding of a tappable settings row. Default `4`.
    public var settingsRowVerticalPadding: CGFloat

    /// Fixed width of a settings row's leading icon gutter. Default `18`.
    public var settingsIconWidth: CGFloat

    /// Width of the disclosure chevron gutter (aligns with the top bar's icon column).
    /// Default `24`.
    public var settingsDisclosureGutter: CGFloat

    /// Letter spacing applied to the uppercased settings section label. Default `0.42`.
    public var settingsSectionLabelTracking: CGFloat

    /// Width of the disclosure section's connector hairline. Default `1`.
    public var settingsConnectorWidth: CGFloat

    /// Opacity multiplier on the resolved subtle stroke for the connector hairline.
    /// Default `0.5`.
    public var settingsConnectorOpacity: CGFloat

    /// Square size of an accent color swatch. Default `18`.
    public var settingsAccentSwatchSize: CGFloat

    /// Stroke width of the selected accent swatch's ring. Default `1.5`.
    public var settingsAccentSwatchStrokeWidth: CGFloat

    /// Opacity multiplier on the resolved primary label for the selected swatch ring.
    /// Default `0.85`.
    public var settingsAccentSwatchSelectedOpacity: CGFloat

    /// Minimum width of a shortcut key cap. Default `24`.
    public var shortcutKeyCapMinWidth: CGFloat

    /// Minimum height of a shortcut key cap. Default `22`.
    public var shortcutKeyCapMinHeight: CGFloat

    /// Corner radius of a shortcut key cap. Default `6`.
    public var shortcutKeyCapCornerRadius: CGFloat

    /// Opacity multiplier on the resolved primary label for a shortcut key cap. Default `0.92`.
    public var shortcutKeyCapLabelOpacity: CGFloat

    /// Opacity multiplier on the resolved subtle fill for a shortcut key cap. Default `0.55`.
    public var shortcutKeyCapFillOpacity: CGFloat

    /// Opacity multiplier on the resolved subtle stroke for a shortcut key cap. Default `0.35`.
    public var shortcutKeyCapStrokeOpacity: CGFloat

    /// Stroke width of a shortcut key cap's outline. Default `1`.
    public var shortcutKeyCapStrokeWidth: CGFloat

    /// Horizontal spacing between the shortcut key caps in the show/hide row. Default `4`.
    public var shortcutKeyCapSpacing: CGFloat

    /// Horizontal padding of the hotkey "recording" capsule. Default `10`.
    public var settingsRecordingHorizontalPadding: CGFloat

    /// Minimum height of the hotkey "recording" capsule. Default `22`.
    public var settingsRecordingMinHeight: CGFloat

    /// Opacity multiplier on the resolved subtle fill for the recording capsule. Default `0.7`.
    public var settingsRecordingFillOpacity: CGFloat

    /// Opacity multiplier on the resolved accent for the recording capsule outline.
    /// Default `0.6`.
    public var settingsRecordingStrokeOpacity: CGFloat

    /// Stroke width of the recording capsule's outline. Default `1`.
    public var settingsRecordingStrokeWidth: CGFloat

    /// Opacity multiplier on the resolved primary label for emphasized settings titles
    /// (shortcut row title, About product name). Default `0.95`.
    public var settingsTitleEmphasisOpacity: CGFloat

    /// Opacity multiplier on the resolved primary label for the recording capsule label.
    /// Default `0.9`.
    public var settingsRecordingLabelOpacity: CGFloat

    /// Vertical spacing between stacked hotkey-registration failure rows. Default `4`.
    public var settingsFailureRowSpacing: CGFloat

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
        bannerStrokeWidth: CGFloat = 0.5,
        shelfContentSpacing: CGFloat = 8,
        shelfRootVerticalPadding: CGFloat = 6,
        shelfDropZoneVerticalPadding: CGFloat = 28,
        shelfDropZoneCornerRadius: CGFloat = 12,
        shelfDropZoneStrokeWidth: CGFloat = 1,
        shelfHeaderSpacing: CGFloat = 10,
        shelfChipSpacing: CGFloat = 4,
        shelfChipWidth: CGFloat = 72,
        shelfChipPadding: CGFloat = 8,
        shelfChipCornerRadius: CGFloat = 10,
        shelfIconSize: CGFloat = 34,
        shelfRowVerticalPadding: CGFloat = 2,
        activityCardSpacing: CGFloat = 12,
        activityIconWidth: CGFloat = 30,
        activityTextSpacing: CGFloat = 2,
        activityCardVerticalPadding: CGFloat = 16,
        activityCardHorizontalPadding: CGFloat = 8,
        volumeGlyphOpacity: CGFloat = 0.85,
        placeholderStackSpacing: CGFloat = 10,
        placeholderMarkSize: CGFloat = 28,
        placeholderMarkStrokeWidth: CGFloat = 2,
        placeholderVerticalPadding: CGFloat = 40,
        settingsSectionSpacing: CGFloat = 16,
        settingsGroupSpacing: CGFloat = 12,
        settingsRowSpacing: CGFloat = 10,
        settingsBlockSpacing: CGFloat = 10,
        settingsFieldSpacing: CGFloat = 5,
        settingsTextSpacing: CGFloat = 2,
        settingsAboutTextSpacing: CGFloat = 3,
        settingsInlineSpacing: CGFloat = 6,
        settingsContentBottomPadding: CGFloat = 14,
        settingsRowVerticalPadding: CGFloat = 4,
        settingsIconWidth: CGFloat = 18,
        settingsDisclosureGutter: CGFloat = 24,
        settingsSectionLabelTracking: CGFloat = 0.42,
        settingsConnectorWidth: CGFloat = 1,
        settingsConnectorOpacity: CGFloat = 0.5,
        settingsAccentSwatchSize: CGFloat = 18,
        settingsAccentSwatchStrokeWidth: CGFloat = 1.5,
        settingsAccentSwatchSelectedOpacity: CGFloat = 0.85,
        shortcutKeyCapMinWidth: CGFloat = 24,
        shortcutKeyCapMinHeight: CGFloat = 22,
        shortcutKeyCapCornerRadius: CGFloat = 6,
        shortcutKeyCapLabelOpacity: CGFloat = 0.92,
        shortcutKeyCapFillOpacity: CGFloat = 0.55,
        shortcutKeyCapStrokeOpacity: CGFloat = 0.35,
        shortcutKeyCapStrokeWidth: CGFloat = 1,
        shortcutKeyCapSpacing: CGFloat = 4,
        settingsRecordingHorizontalPadding: CGFloat = 10,
        settingsRecordingMinHeight: CGFloat = 22,
        settingsRecordingFillOpacity: CGFloat = 0.7,
        settingsRecordingStrokeOpacity: CGFloat = 0.6,
        settingsRecordingStrokeWidth: CGFloat = 1,
        settingsTitleEmphasisOpacity: CGFloat = 0.95,
        settingsRecordingLabelOpacity: CGFloat = 0.9,
        settingsFailureRowSpacing: CGFloat = 4
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
        self.shelfContentSpacing = shelfContentSpacing
        self.shelfRootVerticalPadding = shelfRootVerticalPadding
        self.shelfDropZoneVerticalPadding = shelfDropZoneVerticalPadding
        self.shelfDropZoneCornerRadius = shelfDropZoneCornerRadius
        self.shelfDropZoneStrokeWidth = shelfDropZoneStrokeWidth
        self.shelfHeaderSpacing = shelfHeaderSpacing
        self.shelfChipSpacing = shelfChipSpacing
        self.shelfChipWidth = shelfChipWidth
        self.shelfChipPadding = shelfChipPadding
        self.shelfChipCornerRadius = shelfChipCornerRadius
        self.shelfIconSize = shelfIconSize
        self.shelfRowVerticalPadding = shelfRowVerticalPadding
        self.activityCardSpacing = activityCardSpacing
        self.activityIconWidth = activityIconWidth
        self.activityTextSpacing = activityTextSpacing
        self.activityCardVerticalPadding = activityCardVerticalPadding
        self.activityCardHorizontalPadding = activityCardHorizontalPadding
        self.volumeGlyphOpacity = volumeGlyphOpacity
        self.placeholderStackSpacing = placeholderStackSpacing
        self.placeholderMarkSize = placeholderMarkSize
        self.placeholderMarkStrokeWidth = placeholderMarkStrokeWidth
        self.placeholderVerticalPadding = placeholderVerticalPadding
        self.settingsSectionSpacing = settingsSectionSpacing
        self.settingsGroupSpacing = settingsGroupSpacing
        self.settingsRowSpacing = settingsRowSpacing
        self.settingsBlockSpacing = settingsBlockSpacing
        self.settingsFieldSpacing = settingsFieldSpacing
        self.settingsTextSpacing = settingsTextSpacing
        self.settingsAboutTextSpacing = settingsAboutTextSpacing
        self.settingsInlineSpacing = settingsInlineSpacing
        self.settingsContentBottomPadding = settingsContentBottomPadding
        self.settingsRowVerticalPadding = settingsRowVerticalPadding
        self.settingsIconWidth = settingsIconWidth
        self.settingsDisclosureGutter = settingsDisclosureGutter
        self.settingsSectionLabelTracking = settingsSectionLabelTracking
        self.settingsConnectorWidth = settingsConnectorWidth
        self.settingsConnectorOpacity = settingsConnectorOpacity
        self.settingsAccentSwatchSize = settingsAccentSwatchSize
        self.settingsAccentSwatchStrokeWidth = settingsAccentSwatchStrokeWidth
        self.settingsAccentSwatchSelectedOpacity = settingsAccentSwatchSelectedOpacity
        self.shortcutKeyCapMinWidth = shortcutKeyCapMinWidth
        self.shortcutKeyCapMinHeight = shortcutKeyCapMinHeight
        self.shortcutKeyCapCornerRadius = shortcutKeyCapCornerRadius
        self.shortcutKeyCapLabelOpacity = shortcutKeyCapLabelOpacity
        self.shortcutKeyCapFillOpacity = shortcutKeyCapFillOpacity
        self.shortcutKeyCapStrokeOpacity = shortcutKeyCapStrokeOpacity
        self.shortcutKeyCapStrokeWidth = shortcutKeyCapStrokeWidth
        self.shortcutKeyCapSpacing = shortcutKeyCapSpacing
        self.settingsRecordingHorizontalPadding = settingsRecordingHorizontalPadding
        self.settingsRecordingMinHeight = settingsRecordingMinHeight
        self.settingsRecordingFillOpacity = settingsRecordingFillOpacity
        self.settingsRecordingStrokeOpacity = settingsRecordingStrokeOpacity
        self.settingsRecordingStrokeWidth = settingsRecordingStrokeWidth
        self.settingsTitleEmphasisOpacity = settingsTitleEmphasisOpacity
        self.settingsRecordingLabelOpacity = settingsRecordingLabelOpacity
        self.settingsFailureRowSpacing = settingsFailureRowSpacing
    }

    /// The framework-default metrics - reproduces today's layout.
    public static let `default` = NookChromeMetrics()
}

private struct NookChromeMetricsKey: EnvironmentKey {
    static let defaultValue: NookChromeMetrics = .default
}

extension EnvironmentValues {
    /// Host-tunable chrome layout metrics. See ``NookChromeMetrics``.
    public var nookChromeMetrics: NookChromeMetrics {
        get { self[NookChromeMetricsKey.self] }
        set { self[NookChromeMetricsKey.self] = newValue }
    }
}
