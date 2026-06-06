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

    // Matches `NookView`'s expanded-content safe-area strip — the historical
    // fixed geometry (`NookStyle.standardExpandedContentInsets`): 0 top, 8 elsewhere.
    private let chromeSafeAreaInsets = NookStyle.standardExpandedContentInsets

    // MARK: - Defaults

    func testZeroIsAllZeros() {
        let insets = NookContentInsets.zero
        XCTAssertEqual(insets.top, 0)
        XCTAssertEqual(insets.bottom, 0)
        XCTAssertEqual(insets.leading, 0)
        XCTAssertEqual(insets.trailing, 0)
    }

    // MARK: - Default wiring

    /// Guards the wiring default, not just the derivation math: `NookStyle.standard`
    /// (and any `NookStyle` built without overriding `expandedContentInsets`) must
    /// carry the historical strip — 0 on top, 8 on the other three edges. A future
    /// edit to the default would silently reshape the shipped geometry without this.
    func testStandardStyleCarriesLegacyExpandedInsets() {
        let expected = NookEdgeInsets(top: 0, bottom: 8, leading: 8, trailing: 8)
        XCTAssertEqual(NookStyle.standardExpandedContentInsets, expected)
        XCTAssertEqual(NookStyle.standard.expandedContentInsets, expected)
        // The corner-radius-only initializer must default to the same strip.
        XCTAssertEqual(
            NookStyle(topCornerRadius: 19, bottomCornerRadius: 24).expandedContentInsets,
            expected
        )
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
            chromeSafeAreaInsets: chromeSafeAreaInsets
        )
        XCTAssertEqual(insets.top, 19)
        XCTAssertEqual(insets.bottom, 16)
        XCTAssertEqual(insets.leading, 16)
        XCTAssertEqual(insets.trailing, 16)
    }

    /// The default `expandedContentInsets` must reproduce the historical fixed
    /// geometry exactly: a uniform 8 pt strip on bottom/leading/trailing and 0 on
    /// top is equivalent to feeding the old scalar `8` to the derivation. This pins
    /// the "default == old behavior" contract so the new per-edge knob can't drift
    /// the shipped geometry.
    func testNotchExpandedDefaultInsetsMatchLegacyScalar() {
        let perEdge = NookContentInsets.expanded(
            form: .notch,
            topCornerRadius: 15,
            bottomCornerRadius: 20,
            chromeSafeAreaInsets: NookStyle.standardExpandedContentInsets
        )
        let legacyEquivalent = NookContentInsets.expanded(
            form: .notch,
            topCornerRadius: 15,
            bottomCornerRadius: 20,
            chromeSafeAreaInsets: NookEdgeInsets(top: 0, bottom: 8, leading: 8, trailing: 8)
        )
        XCTAssertEqual(perEdge, legacyEquivalent)
        // And the concrete numbers at the `.standard` radii (top 15, bottom 20).
        XCTAssertEqual(perEdge.top, 15)
        XCTAssertEqual(perEdge.bottom, 12)
        XCTAssertEqual(perEdge.leading, 12)
        XCTAssertEqual(perEdge.trailing, 12)
    }

    /// Tightening only the bottom inset (8 → 2) leaves top/leading/trailing untouched
    /// and *raises* the bottom residual: with 6 pt less chrome pre-padding, content
    /// pinned into a bottom corner must inset 6 pt more to clear the same curve. The
    /// chrome's own bottom safe-area strip shrinks by 6 pt, so centered content sits
    /// ~6 pt closer to the rounded bottom.
    func testNotchExpandedReducedBottomInset() {
        let reduced = NookEdgeInsets(top: 0, bottom: 2, leading: 8, trailing: 8)
        let insets = NookContentInsets.expanded(
            form: .notch,
            topCornerRadius: 19,
            bottomCornerRadius: 24,
            chromeSafeAreaInsets: reduced
        )
        // Unchanged from the default-inset case.
        XCTAssertEqual(insets.top, 19)
        XCTAssertEqual(insets.leading, 16)
        XCTAssertEqual(insets.trailing, 16)
        // 24 − 2 = 22, vs 16 at the default 8 pt bottom inset: +6 pt of residual
        // corner clearance, mirroring the 6 pt the chrome no longer pre-pads.
        XCTAssertEqual(insets.bottom, 22)
    }

    /// The chrome's horizontal pre-pad is `topCornerRadius + chromeSafeAreaInset`.
    /// A `bottomCornerRadius` equal to that threshold has zero horizontal
    /// residual — the chrome already insets exactly enough horizontally to
    /// clear the bottom-corner flare.
    func testNotchExpandedHorizontalResidualClampsAtZero() {
        let insets = NookContentInsets.expanded(
            form: .notch,
            topCornerRadius: 19,
            bottomCornerRadius: 8, // == the bottom/leading/trailing inset
            chromeSafeAreaInsets: chromeSafeAreaInsets
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
            chromeSafeAreaInsets: chromeSafeAreaInsets
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
