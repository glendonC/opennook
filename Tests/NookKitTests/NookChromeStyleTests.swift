// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI
import XCTest
@testable import NookKit

/// Seam C — chrome labels, layout metrics, in-panel motion, and the status/severity
/// channel. Defaults reproduce today's chrome; the configuration carries host overrides.
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
}
