// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Host-tunable fonts for the framework's own text and glyphs - the chrome (top bar,
/// compact pill, status banner) and the optional ``NookComponents`` add-ons. Defaults
/// reproduce today's typography exactly.
///
/// Each role is a `Font`; the framework defaults are built with `.system(size:weight:)`
/// and carry no explicit design, so the chrome's ``NookResolvedTheme/fontDesign`` still
/// cascades over them (applied once on the expanded surface). Supply a role with an
/// explicit design only to override that for a single element.
///
/// This restyles the *framework's* type, not host-supplied content - a registered home
/// view, custom Settings, or trailing items control their own fonts.
///
/// Set via ``NookConfiguration/typography``. The values reach the views through the chrome
/// environment (``EnvironmentValues/nookChromeTypography``).
public struct NookChromeTypography: Sendable, Equatable {

    // MARK: - Top bar

    /// The lock / gear / home glyphs on the top bar (the `HeaderIcon` views).
    public var headerIcon: Font

    /// The leading-cluster title, the Settings and module breadcrumb labels, and the
    /// module switcher's active-module label - the bar's regular-weight text.
    public var topBarLabel: Font

    /// The `chevron.right` separator drawn before a Settings or module breadcrumb.
    public var breadcrumbChevron: Font

    /// The `chevron.down` disclosure glyph on the in-surface module switcher.
    public var switcherChevron: Font

    // MARK: - Compact pill

    /// The default compact pill's leading glyph (the `house` symbol).
    public var compactLeadingGlyph: Font

    // MARK: - Status banner

    /// The status banner's leading severity glyph.
    public var bannerSeverityGlyph: Font

    /// The status banner's message text.
    public var bannerMessage: Font

    /// The status banner's trailing dismiss (`xmark`) glyph.
    public var bannerDismissGlyph: Font

    // MARK: - Components (opt-in NookComponents add-ons)

    /// The file shelf's empty-state tray glyph.
    public var shelfDropZoneIcon: Font

    /// The file shelf's regular-weight secondary text (drop-zone caption, Clear button).
    public var shelfCaption: Font

    /// The file shelf header's medium-weight controls (file count, import `+`).
    public var shelfHeaderLabel: Font

    /// A shelf item chip's filename label.
    public var shelfChipLabel: Font

    /// The shelf item chip's fallback glyph when no file icon is available.
    public var shelfFallbackGlyph: Font

    /// The shelf item chip's hover-revealed remove glyph.
    public var shelfRemoveGlyph: Font

    /// The activity card's leading icon.
    public var activityIcon: Font

    /// The activity card's title.
    public var activityTitle: Font

    /// The activity card's subtitle.
    public var activitySubtitle: Font

    /// The ambient volume indicator's speaker glyph.
    public var volumeGlyph: Font

    // MARK: - Placeholder home

    /// The default placeholder home view's title.
    public var placeholderTitle: Font

    /// The default placeholder home view's body text.
    public var placeholderBody: Font

    // MARK: - Settings panel

    /// A settings section header label (rendered uppercased).
    public var settingsSectionLabel: Font

    /// A small settings hint or failure line (shortcut subtitle, registration failure).
    public var settingsHint: Font

    /// Settings caption / description text (picker descriptions, About tagline).
    public var settingsCaption: Font

    /// The About card's monospaced version string.
    public var settingsVersionLabel: Font

    /// A settings field label above a picker, slider, or swatch row.
    public var settingsFieldLabel: Font

    /// The trailing disclosure chevron on a Data command row.
    public var settingsCommandChevron: Font

    /// A settings row's detail / subtitle text.
    public var settingsRowDetail: Font

    /// A settings row's medium-weight title (shortcut row, failure name, key cap).
    public var settingsRowTitle: Font

    /// A settings emphasis glyph or label (row icons, About product name).
    public var settingsEmphasis: Font

    /// A settings command row's title (action line, data command).
    public var settingsCommandTitle: Font

    /// A settings command row's leading icon.
    public var settingsCommandIcon: Font

    /// The collapsible settings section's disclosure chevron.
    public var settingsDisclosureChevron: Font

    public init(
        headerIcon: Font = .system(size: 11, weight: .semibold),
        topBarLabel: Font = .system(size: 11, weight: .regular),
        breadcrumbChevron: Font = .system(size: 8, weight: .bold),
        switcherChevron: Font = .system(size: 7, weight: .semibold),
        compactLeadingGlyph: Font = .system(size: 10, weight: .semibold),
        bannerSeverityGlyph: Font = .system(size: 11, weight: .semibold),
        bannerMessage: Font = .system(size: 10.5, weight: .medium),
        bannerDismissGlyph: Font = .system(size: 9, weight: .bold),
        shelfDropZoneIcon: Font = .system(size: 24, weight: .light),
        shelfCaption: Font = .system(size: 11),
        shelfHeaderLabel: Font = .system(size: 11, weight: .medium),
        shelfChipLabel: Font = .system(size: 10, weight: .medium),
        shelfFallbackGlyph: Font = .system(size: 30, weight: .light),
        shelfRemoveGlyph: Font = .system(size: 13),
        activityIcon: Font = .system(size: 24, weight: .medium),
        activityTitle: Font = .system(size: 13, weight: .semibold),
        activitySubtitle: Font = .system(size: 11),
        volumeGlyph: Font = .system(size: 11, weight: .semibold),
        placeholderTitle: Font = .system(size: 14, weight: .medium),
        placeholderBody: Font = .system(size: 11, weight: .regular),
        settingsSectionLabel: Font = .system(size: 9, weight: .semibold),
        settingsHint: Font = .system(size: 9, weight: .regular),
        settingsCaption: Font = .system(size: 10, weight: .regular),
        settingsVersionLabel: Font = .system(size: 10, weight: .regular, design: .monospaced),
        settingsFieldLabel: Font = .system(size: 10, weight: .medium),
        settingsCommandChevron: Font = .system(size: 10, weight: .bold),
        settingsRowDetail: Font = .system(size: 11, weight: .regular),
        settingsRowTitle: Font = .system(size: 11, weight: .medium),
        settingsEmphasis: Font = .system(size: 11, weight: .semibold),
        settingsCommandTitle: Font = .system(size: 12, weight: .regular),
        settingsCommandIcon: Font = .system(size: 12, weight: .semibold),
        settingsDisclosureChevron: Font = .system(size: 8, weight: .bold)
    ) {
        self.headerIcon = headerIcon
        self.topBarLabel = topBarLabel
        self.breadcrumbChevron = breadcrumbChevron
        self.switcherChevron = switcherChevron
        self.compactLeadingGlyph = compactLeadingGlyph
        self.bannerSeverityGlyph = bannerSeverityGlyph
        self.bannerMessage = bannerMessage
        self.bannerDismissGlyph = bannerDismissGlyph
        self.shelfDropZoneIcon = shelfDropZoneIcon
        self.shelfCaption = shelfCaption
        self.shelfHeaderLabel = shelfHeaderLabel
        self.shelfChipLabel = shelfChipLabel
        self.shelfFallbackGlyph = shelfFallbackGlyph
        self.shelfRemoveGlyph = shelfRemoveGlyph
        self.activityIcon = activityIcon
        self.activityTitle = activityTitle
        self.activitySubtitle = activitySubtitle
        self.volumeGlyph = volumeGlyph
        self.placeholderTitle = placeholderTitle
        self.placeholderBody = placeholderBody
        self.settingsSectionLabel = settingsSectionLabel
        self.settingsHint = settingsHint
        self.settingsCaption = settingsCaption
        self.settingsVersionLabel = settingsVersionLabel
        self.settingsFieldLabel = settingsFieldLabel
        self.settingsCommandChevron = settingsCommandChevron
        self.settingsRowDetail = settingsRowDetail
        self.settingsRowTitle = settingsRowTitle
        self.settingsEmphasis = settingsEmphasis
        self.settingsCommandTitle = settingsCommandTitle
        self.settingsCommandIcon = settingsCommandIcon
        self.settingsDisclosureChevron = settingsDisclosureChevron
    }

    /// The framework-default chrome typography - reproduces today's fonts.
    public static let `default` = NookChromeTypography()
}

private struct NookChromeTypographyKey: EnvironmentKey {
    static let defaultValue: NookChromeTypography = .default
}

extension EnvironmentValues {
    /// Host-tunable chrome typography. See ``NookChromeTypography``.
    public var nookChromeTypography: NookChromeTypography {
        get { self[NookChromeTypographyKey.self] }
        set { self[NookChromeTypographyKey.self] = newValue }
    }
}
