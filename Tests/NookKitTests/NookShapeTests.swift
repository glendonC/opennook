// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the MIT License.
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI
import XCTest

@testable import NookSurface

/// Coverage for ``NookShape``: the two path constructions, the radius clamp on the
/// floating form (so a small compact pill can't draw a self-intersecting path), and
/// the `animatableData` round-trip that the chrome relies on for smooth radius
/// interpolation.
@MainActor
final class NookShapeTests: XCTestCase {

    // MARK: - animatableData round-trip

    /// `animatableData` is the seam SwiftUI animates radii through. Getting and setting
    /// it must round-trip both values without re-ordering — the chrome's compact-to-
    /// expanded radius spring depends on it.
    func testAnimatableDataRoundTrip() {
        var shape = NookShape(form: .floating, topCornerRadius: 8, bottomCornerRadius: 24)
        XCTAssertEqual(shape.animatableData.first, 8)
        XCTAssertEqual(shape.animatableData.second, 24)

        shape.animatableData = .init(12, 30)
        XCTAssertEqual(shape.animatableData.first, 12)
        XCTAssertEqual(shape.animatableData.second, 30)
    }

    // MARK: - Floating path: radius clamp

    /// When the rect is smaller than 2×radius, the floating path must clamp the
    /// radii so the path stays inside `rect` and the curves don't overrun. Without
    /// the clamp, a small compact pill (width < 2×topCornerRadius) draws a
    /// self-intersecting path that renders as a glitchy crescent.
    func testFloatingPathClampsRadiiOnSmallRects() {
        // Top radius 40, bottom radius 40, but the rect is only 30×30 — both must clamp
        // to 15 (the half-min).
        let tiny = CGRect(x: 0, y: 0, width: 30, height: 30)
        let path = NookShape(form: .floating, topCornerRadius: 40, bottomCornerRadius: 40)
            .path(in: tiny)

        // Bounding box stays inside the host rect (no overrun).
        let bounds = path.boundingRect
        XCTAssertGreaterThanOrEqual(bounds.minX, tiny.minX - 0.001)
        XCTAssertGreaterThanOrEqual(bounds.minY, tiny.minY - 0.001)
        XCTAssertLessThanOrEqual(bounds.maxX, tiny.maxX + 0.001)
        XCTAssertLessThanOrEqual(bounds.maxY, tiny.maxY + 0.001)
        XCTAssertFalse(path.isEmpty)
    }

    /// Negative radii (a hostile or animation-overshoot value) clamp to zero rather
    /// than producing inverted curves.
    func testFloatingPathHandlesNegativeRadii() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
        let path = NookShape(form: .floating, topCornerRadius: -8, bottomCornerRadius: -20)
            .path(in: rect)

        // A zero-radius rect is exactly the host bounds.
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.width, rect.width, accuracy: 0.5)
        XCTAssertEqual(bounds.height, rect.height, accuracy: 0.5)
    }

    /// A normal-sized floating rect produces a closed convex path that occupies the
    /// full host rectangle (the corner cut-outs are tiny relative to the bounding box).
    func testFloatingPathFillsLargeRect() {
        let rect = CGRect(x: 0, y: 0, width: 520, height: 220)
        let path = NookShape(form: .floating, topCornerRadius: 16, bottomCornerRadius: 24)
            .path(in: rect)
        let bounds = path.boundingRect

        // The path's bounding box must equal the host rect — a missing corner curve
        // would produce a smaller box.
        XCTAssertEqual(bounds.minX, rect.minX, accuracy: 0.5)
        XCTAssertEqual(bounds.maxX, rect.maxX, accuracy: 0.5)
        XCTAssertEqual(bounds.minY, rect.minY, accuracy: 0.5)
        XCTAssertEqual(bounds.maxY, rect.maxY, accuracy: 0.5)
    }

    // MARK: - Notch path

    /// The notch path's bounding box is the host rect — the eared top edge curves
    /// inward, not outward.
    func testNotchPathBoundingBoxMatchesHostRect() {
        let rect = CGRect(x: 0, y: 0, width: 520, height: 220)
        let path = NookShape(form: .notch, topCornerRadius: 19, bottomCornerRadius: 24)
            .path(in: rect)
        let bounds = path.boundingRect

        XCTAssertEqual(bounds.minX, rect.minX, accuracy: 0.5)
        XCTAssertEqual(bounds.maxX, rect.maxX, accuracy: 0.5)
        XCTAssertEqual(bounds.minY, rect.minY, accuracy: 0.5)
        XCTAssertEqual(bounds.maxY, rect.maxY, accuracy: 0.5)
    }
}
