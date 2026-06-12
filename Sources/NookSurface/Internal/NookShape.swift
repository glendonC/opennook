// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// The chrome's outline. Two forms, selected by ``NookChromeForm``:
///
/// - ``NookChromeForm/notch`` - a notch-following shape: the top edge flares to full
///   width then curves *inward* by `topCornerRadius`, so the ears fuse flush with the
///   menu bar on either side of a physical notch; larger bottom-corners where the
///   panel meets the wallpaper.
/// - ``NookChromeForm/floating`` - a plain convex rounded rectangle, for a free-floating
///   panel on a display with no notch.
///
/// `form` is a discrete per-window configuration and isn't animated; the two corner
/// radii are, so a compact<->expanded transition still springs smoothly within a form.
struct NookShape: Shape {
    private let form: NookChromeForm
    private var topCornerRadius: CGFloat
    private var bottomCornerRadius: CGFloat

    init(form: NookChromeForm = .notch, topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) {
        self.form = form
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        switch form {
        case .notch: return notchPath(in: rect)
        case .floating: return floatingPath(in: rect)
        }
    }

    private func notchPath(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return path
    }

    /// Convex rounded rectangle flush to `rect`, with independent top and bottom corner
    /// radii. No flared ears - this is a panel that floats on its own, not one fused to
    /// a notch. Radii are clamped so they can't overrun a small compact pill.
    private func floatingPath(in rect: CGRect) -> Path {
        let limit = min(rect.width, rect.height) / 2
        let rt = max(min(topCornerRadius, limit), 0)
        let rb = max(min(bottomCornerRadius, limit), 0)

        var path = Path()

        path.move(to: CGPoint(x: rect.minX + rt, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - rt, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rt),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rb))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rb, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.minX + rb, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - rb),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rt))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rt, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        path.closeSubpath()
        return path
    }
}
