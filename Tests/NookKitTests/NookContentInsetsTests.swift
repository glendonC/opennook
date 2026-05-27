// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest

@testable import NookSurface

/// Coverage for ``NookContentInsets`` and its derivation against the chrome's
/// expanded geometry. The chrome's clip shape (`NookShape`) and the env-value
/// derivation must not drift, so these tests pin the residual math at the
/// numbers `NookKit` ships by default and at the threshold cases where the
/// chrome's own pre-padding stops clearing a curve.
final class NookContentInsetsTests: XCTestCase {

    // Matches `NookView.safeAreaInset`.
    private let chromeSafeAreaInset: CGFloat = 8

    // MARK: - Defaults

    func testZeroIsAllZeros() {
        let insets = NookContentInsets.zero
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.bottom, 0)
        XCTAssertEqual(insets.leading, 0)
        XCTAssertEqual(insets.trailing, 0)
    }

    // MARK: - Notch form

    /// At the radii NookKit ships (top 19, bottom 24), the residuals reduce to:
    /// top = full topCornerRadius (chrome doesn't pre-pad the top), bottom and
    /// sides = bottomCornerRadius - chromeSafeAreaInset.
    func testNotchExpandedAtNookKitDefaults() {
        let insets = NookContentInsets.expanded(
            form: .notch,
            topCornerRadius: 19,
            bottomCornerRadius: 24,
            chromeSafeAreaInset: chromeSafeAreaInset
        )
        XCTAssertEqual(insets.top, 19)
        XCTAssertEqual(insets.bottom, 16)
        XCTAssertEqual(insets.leading, 16)
        XCTAssertEqual(insets.trailing, 16)
    }

    /// The chrome's horizontal pre-pad is `topCornerRadius + chromeSafeAreaInset`.
    /// A `bottomCornerRadius` equal to that threshold has zero horizontal
    /// residual — the chrome already insets exactly enough horizontally to
    /// clear the bottom-corner flare.
    func testNotchExpandedHorizontalResidualClampsAtZero() {
        let insets = NookContentInsets.expanded(
            form: .notch,
            topCornerRadius: 19,
            bottomCornerRadius: chromeSafeAreaInset, // 8
            chromeSafeAreaInset: chromeSafeAreaInset
        )
        XCTAssertEqual(insets.leading, 0, "horizontal residual must floor at 0")
        XCTAssertEqual(insets.trailing, 0)
        XCTAssertEqual(insets.bottom, 0, "bottom residual floors when curve fits in chrome's bottom inset")
    }

    // MARK: - Floating form

    /// Floating uses `bottomCornerRadius` for every corner. Top is the full
    /// radius (no top pre-pad); bottom subtracts the chrome's bottom inset;
    /// sides subtract `topCornerRadius + chromeSafeAreaInset` (the form-agnostic
    /// horizontal pre-pad), so they floor at zero in the default config.
    func testFloatingExpandedAtNookKitDefaults() {
        let insets = NookContentInsets.expanded(
            form: .floating,
            topCornerRadius: 19,
            bottomCornerRadius: 24,
            chromeSafeAreaInset: chromeSafeAreaInset
        )
        XCTAssertEqual(insets.top, 24)
        XCTAssertEqual(insets.bottom, 16)
        XCTAssertEqual(insets.leading, 0)
        XCTAssertEqual(insets.trailing, 0)
    }

    // MARK: - reducingBy

    /// `reducingBy` is what wrapper views (e.g. `NookExpandedView`) use to
    /// re-inject insets relative to their inner frame after they add their own
    /// padding. Each axis subtracts, floored at zero.
    func testReducingBySubtractsAndFloorsAtZero() {
        let insets = NookContentInsets(top: 19, bottom: 16, leading: 16, trailing: 16)
        let reduced = insets.reducingBy(8)
        XCTAssertEqual(reduced.top, 11)
        XCTAssertEqual(reduced.bottom, 8)
        XCTAssertEqual(reduced.leading, 8)
        XCTAssertEqual(reduced.trailing, 8)

        let overReduced = insets.reducingBy(40)
        XCTAssertEqual(overReduced.top, 0)
        XCTAssertEqual(overReduced.bottom, 0)
        XCTAssertEqual(overReduced.leading, 0)
        XCTAssertEqual(overReduced.trailing, 0)
    }
}
