// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Host-tunable fonts for the framework chrome's own text and glyphs - the top bar, the
/// compact pill, and the transient status banner. Defaults reproduce today's typography
/// exactly.
///
/// Each role is a `Font`; the framework defaults are built with `.system(size:weight:)`
/// and carry no explicit design, so the chrome's ``NookResolvedTheme/fontDesign`` still
/// cascades over them (applied once on the expanded surface). Supply a role with an
/// explicit design only to override that for a single element.
///
/// This restyles the *chrome's* type, not host-supplied content - a registered home
/// view, custom Settings, or trailing items control their own fonts.
///
/// Set via ``NookConfiguration/typography``. The values reach the views through the chrome
/// environment (``EnvironmentValues/nookChromeTypography``).
public struct NookChromeTypography: Sendable, Equatable {
    /// The lock / gear / home glyphs on the top bar (the `HeaderIcon` views).
    public var headerIcon: Font

    /// The leading-cluster title, the Settings and module breadcrumb labels, and the
    /// module switcher's active-module label - the bar's regular-weight text.
    public var topBarLabel: Font

    /// The `chevron.right` separator drawn before a Settings or module breadcrumb.
    public var breadcrumbChevron: Font

    /// The `chevron.down` disclosure glyph on the in-surface module switcher.
    public var switcherChevron: Font

    /// The default compact pill's leading glyph (the `house` symbol).
    public var compactLeadingGlyph: Font

    /// The status banner's leading severity glyph.
    public var bannerSeverityGlyph: Font

    /// The status banner's message text.
    public var bannerMessage: Font

    /// The status banner's trailing dismiss (`xmark`) glyph.
    public var bannerDismissGlyph: Font

    public init(
        headerIcon: Font = .system(size: 11, weight: .semibold),
        topBarLabel: Font = .system(size: 11, weight: .regular),
        breadcrumbChevron: Font = .system(size: 8, weight: .bold),
        switcherChevron: Font = .system(size: 7, weight: .semibold),
        compactLeadingGlyph: Font = .system(size: 10, weight: .semibold),
        bannerSeverityGlyph: Font = .system(size: 11, weight: .semibold),
        bannerMessage: Font = .system(size: 10.5, weight: .medium),
        bannerDismissGlyph: Font = .system(size: 9, weight: .bold)
    ) {
        self.headerIcon = headerIcon
        self.topBarLabel = topBarLabel
        self.breadcrumbChevron = breadcrumbChevron
        self.switcherChevron = switcherChevron
        self.compactLeadingGlyph = compactLeadingGlyph
        self.bannerSeverityGlyph = bannerSeverityGlyph
        self.bannerMessage = bannerMessage
        self.bannerDismissGlyph = bannerDismissGlyph
    }

    /// The framework-default chrome typography - reproduces today's fonts.
    public static let `default` = NookChromeTypography()
}

private struct NookChromeTypographyKey: EnvironmentKey {
    static let defaultValue: NookChromeTypography = .default
}

public extension EnvironmentValues {
    /// Host-tunable chrome typography. See ``NookChromeTypography``.
    var nookChromeTypography: NookChromeTypography {
        get { self[NookChromeTypographyKey.self] }
        set { self[NookChromeTypographyKey.self] = newValue }
    }
}
