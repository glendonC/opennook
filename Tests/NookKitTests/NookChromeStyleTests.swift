// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI
import XCTest
@testable import NookKit

/// Seam C - chrome labels, layout metrics, typography, in-panel motion, and the
/// status/severity channel. Defaults reproduce today's chrome; the configuration carries
/// host overrides.
@MainActor
final class NookChromeStyleTests: XCTestCase {
    // MARK: - Status + severity

    /// `showStatus` posts a message with the given severity; the `errorMessage` shim
    /// reads the message back.
    func testShowStatusSetsSeverityAndMessage() {
        let state = AppState()
        state.showStatus("Imported 3 files", severity: .success)

        XCTAssertEqual(state.status?.message, "Imported 3 files")
        XCTAssertEqual(state.status?.severity, .success)
        XCTAssertEqual(state.errorMessage, "Imported 3 files")
    }

    /// The back-compatible `errorMessage` setter posts an `.error`-severity status.
    func testErrorMessageShimPostsErrorSeverity() {
        let state = AppState()
        state.errorMessage = "Something broke"

        XCTAssertEqual(state.status?.severity, .error)
        XCTAssertEqual(state.status?.message, "Something broke")
    }

    /// Clearing resets the whole status channel.
    func testResetTransientStatusClearsStatus() {
        let state = AppState()
        state.showStatus("hi", severity: .info)
        state.resetTransientStatus()

        XCTAssertNil(state.status)
        XCTAssertNil(state.errorMessage)
    }

    /// Each severity maps to a distinct SF Symbol.
    func testSeverityGlyphs() {
        XCTAssertEqual(NookStatusSeverity.error.systemImage, "exclamationmark.circle.fill")
        XCTAssertEqual(NookStatusSeverity.warning.systemImage, "exclamationmark.triangle.fill")
        XCTAssertEqual(NookStatusSeverity.info.systemImage, "info.circle.fill")
        XCTAssertEqual(NookStatusSeverity.success.systemImage, "checkmark.circle.fill")
    }

    // MARK: - Labels

    func testLabelsDefaultsReproduceFramework() {
        let labels = NookChromeLabels.default
        XCTAssertEqual(labels.settingsBreadcrumb, "Settings")
        XCTAssertEqual(labels.keepOpenHelp, "Stay expanded after hover")
        XCTAssertEqual(labels.settingsHelp, "Settings")
        XCTAssertEqual(labels.dismissHelp, "Dismiss")

        XCTAssertEqual(NookConfiguration().labels, .default)
    }

    func testLabelsAreHostConfigurable() {
        var configuration = NookConfiguration()
        configuration.labels.settingsBreadcrumb = "Préférences"
        XCTAssertEqual(configuration.labels.settingsBreadcrumb, "Préférences")
    }

    // MARK: - Metrics

    func testMetricsDefaultsMatchLayoutConstants() {
        let metrics = NookChromeMetrics.default
        XCTAssertEqual(metrics.edgePadding, NookLayout.edgePadding)
        XCTAssertEqual(metrics.compactSlotSize, NookLayout.compactSlotSize)
        XCTAssertEqual(metrics.breadcrumbMaxWidth, NookLayout.breadcrumbMaxWidth)
        XCTAssertEqual(metrics.topBarHeight, NookLayout.topBarHeight)

        XCTAssertEqual(NookConfiguration().metrics, .default)
    }

    func testMetricsAreHostConfigurable() {
        var configuration = NookConfiguration()
        configuration.metrics.edgePadding = 12
        configuration.metrics.compactSlotSize = 28
        XCTAssertEqual(configuration.metrics.edgePadding, 12)
        XCTAssertEqual(configuration.metrics.compactSlotSize, 28)
    }

    /// The element-level metrics added for the styling-token pass default to today's
    /// baked-in values, so a plain configuration renders pixel-identically.
    func testExtendedMetricsDefaultsReproduceFramework() {
        let metrics = NookChromeMetrics.default
        // Expanded surface + top bar
        XCTAssertEqual(metrics.expandedColumnSpacing, 8)
        XCTAssertEqual(metrics.topBarItemSpacing, 8)
        XCTAssertEqual(metrics.leadingClusterSpacing, 6)
        XCTAssertEqual(metrics.trailingClusterSpacing, 4)
        // Header icons
        XCTAssertEqual(metrics.headerIconSize, 24)
        XCTAssertEqual(metrics.headerIconCornerRadius, 7)
        XCTAssertEqual(metrics.headerIconStrokeWidth, 1)
        XCTAssertEqual(metrics.headerIconHoverLabelOpacity, 0.92)
        // Leading brand mark
        XCTAssertEqual(metrics.brandMarkSize, 11)
        XCTAssertEqual(metrics.brandMarkStrokeWidth, 1.1)
        XCTAssertEqual(metrics.brandMarkOpacity, 0.92)
        // Compact pill
        XCTAssertEqual(metrics.compactLeadingGlyphOpacity, 0.88)
        XCTAssertEqual(metrics.compactTrailingMarkSize, 11)
        XCTAssertEqual(metrics.compactTrailingMarkStrokeWidth, 1.1)
        XCTAssertEqual(metrics.compactTrailingMarkOpacity, 0.82)
        // Status banner
        XCTAssertEqual(metrics.bannerRowSpacing, 8)
        XCTAssertEqual(metrics.bannerCornerRadius, 10)
        XCTAssertEqual(metrics.bannerContentHorizontalPadding, 10)
        XCTAssertEqual(metrics.bannerContentVerticalPadding, 7)
        XCTAssertEqual(metrics.bannerSeverityGlyphTopInset, 1)
        XCTAssertEqual(metrics.bannerDismissButtonSize, 18)
        XCTAssertEqual(metrics.bannerMessageLabelOpacity, 0.92)
        XCTAssertEqual(metrics.bannerStrokeOpacity, 0.65)
        XCTAssertEqual(metrics.bannerStrokeWidth, 0.5)
    }

    func testExtendedMetricsAreHostConfigurable() {
        var configuration = NookConfiguration()
        configuration.metrics.headerIconCornerRadius = 10
        configuration.metrics.bannerCornerRadius = 14
        XCTAssertEqual(configuration.metrics.headerIconCornerRadius, 10)
        XCTAssertEqual(configuration.metrics.bannerCornerRadius, 14)
        XCTAssertNotEqual(configuration.metrics, .default)
    }

    // MARK: - Typography

    /// The chrome font roles default to today's baked-in fonts, so a plain configuration
    /// renders pixel-identically. Pins each role so a future drift is caught.
    func testTypographyDefaultsReproduceFramework() {
        let typography = NookChromeTypography.default
        XCTAssertEqual(typography.headerIcon, .system(size: 11, weight: .semibold))
        XCTAssertEqual(typography.topBarLabel, .system(size: 11, weight: .regular))
        XCTAssertEqual(typography.breadcrumbChevron, .system(size: 8, weight: .bold))
        XCTAssertEqual(typography.switcherChevron, .system(size: 7, weight: .semibold))
        XCTAssertEqual(typography.compactLeadingGlyph, .system(size: 10, weight: .semibold))
        XCTAssertEqual(typography.bannerSeverityGlyph, .system(size: 11, weight: .semibold))
        XCTAssertEqual(typography.bannerMessage, .system(size: 10.5, weight: .medium))
        XCTAssertEqual(typography.bannerDismissGlyph, .system(size: 9, weight: .bold))

        XCTAssertEqual(NookConfiguration().typography, .default)
    }

    func testTypographyDefaultsAndConfigurable() {
        XCTAssertEqual(NookConfiguration().typography, .default)
        XCTAssertEqual(NookChromeTypography.default, NookChromeTypography())

        var configuration = NookConfiguration()
        configuration.typography.topBarLabel = .system(size: 13, weight: .bold)
        XCTAssertNotEqual(configuration.typography, .default)
        XCTAssertEqual(configuration.typography.topBarLabel, .system(size: 13, weight: .bold))
    }

    // MARK: - Motion

    func testMotionDefaultsAndConfigurable() {
        XCTAssertEqual(NookConfiguration().motion, .default)
        XCTAssertEqual(NookChromeMotion.default, NookChromeMotion())

        var configuration = NookConfiguration()
        configuration.motion.statusBanner = .linear(duration: 1)
        XCTAssertNotEqual(configuration.motion, .default)
    }

    // MARK: - Status banner visibility flag

    func testStatusBannerVisibilityDefaultsOnAndIsConfigurable() {
        XCTAssertTrue(NookConfiguration().topBar.showsStatusBanner)

        var configuration = NookConfiguration()
        configuration.topBar.showsStatusBanner = false
        XCTAssertFalse(configuration.topBar.showsStatusBanner)
    }

    func testTopBarWidthDefaultsToContentColumnAndIsConfigurable() {
        XCTAssertEqual(NookConfiguration().topBar.width, .contentColumn)

        var configuration = NookConfiguration()
        configuration.topBar.width = .intrinsic
        XCTAssertEqual(configuration.topBar.width, .intrinsic)
    }
}
