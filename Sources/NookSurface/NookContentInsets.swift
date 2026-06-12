// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the MIT License.
// See /LICENSE-MIT-NOOKSURFACE for the modifications license.

import SwiftUI

/// Safe-area insets derived from the chrome's panel geometry.
///
/// The notch panel is not a rectangle: the top corners curve inward by
/// `topCornerRadius`, and the bottom corners by `bottomCornerRadius` (plus an
/// extra horizontal carve where the notch shape's bottom flares outward). Content
/// pinned near a corner of the host's expanded view will visually intersect those
/// curves unless it's inset by some amount on each affected edge.
///
/// `NookContentInsets` is the geometric equivalent of UIKit's `safeAreaInsets`,
/// surfaced to SwiftUI through ``EnvironmentValues/nookContentInsets``. The
/// chrome itself consumes this for its own top-bar icon clusters; host apps
/// read it when laying out content that pins to a corner or to a single edge:
///
/// ```swift
/// @Environment(\.nookContentInsets) private var insets
///
/// var body: some View {
///     VStack {
///         Spacer()
///         HStack {
///             Spacer()
///             Text("Disk: 720 MB")
///                 .padding(.trailing, insets.trailing)
///                 .padding(.bottom, insets.bottom)
///         }
///     }
/// }
/// ```
///
/// The values represent residual clearance - the chrome's own pre-applied
/// paddings (the horizontal inset by `topCornerRadius`, the small bottom
/// safe-area strip) are already subtracted, so an inset of `0` means "the
/// chrome's geometry doesn't intrude into your frame on that edge."
///
/// Re-injection: a wrapper that adds its own padding around the host content
/// (the way ``NookExpandedView`` does) should subtract that padding and
/// re-inject the adjusted insets, so descendants see a value relative to their
/// own frame. Floor at zero so a generously-padded wrapper reports `.zero`
/// rather than negative numbers.
public struct NookContentInsets: Equatable, Sendable {
    /// Clearance on the top edge of the content frame.
    public var top: CGFloat
    /// Clearance on the bottom edge of the content frame.
    public var bottom: CGFloat
    /// Clearance on the leading edge of the content frame.
    public var leading: CGFloat
    /// Clearance on the trailing edge of the content frame.
    public var trailing: CGFloat

    public init(top: CGFloat = 0, bottom: CGFloat = 0, leading: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.bottom = bottom
        self.leading = leading
        self.trailing = trailing
    }

    /// No clearance needed - the default before the chrome computes its
    /// geometry (and the value reported in `.compact`/`.hidden`, where no host
    /// expanded content is laid out).
    public static let zero = NookContentInsets()
}

extension NookContentInsets {
    /// Derives the residual safe-area insets for the chrome's expanded geometry,
    /// relative to the host's expanded view frame.
    ///
    /// Internal to `NookSurface`: this is the formula `NookView` injects into the
    /// environment. Pulled out as a pure function so the chrome's clip geometry
    /// and the env value can't drift, and so tests can pin the math without
    /// driving the full view tree.
    ///
    /// `chromeSafeAreaInsets` is the per-edge strip the chrome reserves around the
    /// host's expanded view (see ``NookStyle/expandedContentInsets``). With the
    /// default (`top: 0`) the full top corner curvature lands inside the host frame
    /// and the top residual returns `topCornerRadius`. The notch form's bottom corner
    /// also flares outward horizontally by `bottomCornerRadius` beyond the side edges,
    /// so the leading/trailing residual depends on `bottomCornerRadius`, not
    /// `topCornerRadius`.
    ///
    /// Each residual is `curve − chromePrePad`, floored at zero: the curve intrudes
    /// into the host frame by however much it exceeds the chrome's own inset on that
    /// edge. Tightening `chromeSafeAreaInsets.bottom` therefore *raises* the reported
    /// bottom residual - with less pre-padding, a host pinning content into a bottom
    /// *corner* must inset more itself to clear the curve. Horizontally-centered
    /// content stays clear of the corners and can ignore the residual.
    static func expanded(
        form: NookChromeForm,
        topCornerRadius: CGFloat,
        bottomCornerRadius: CGFloat,
        chromeSafeAreaInsets: NookEdgeInsets
    ) -> NookContentInsets {
        let leadingPrePad = topCornerRadius + chromeSafeAreaInsets.leading
        let trailingPrePad = topCornerRadius + chromeSafeAreaInsets.trailing
        let bottomPrePad = chromeSafeAreaInsets.bottom
        let topPrePad = chromeSafeAreaInsets.top

        switch form {
        case .notch:
            let topV = max(0, topCornerRadius - topPrePad)
            let bottomV = max(0, bottomCornerRadius - bottomPrePad)
            // The bottom-leading bezier runs from x = topCornerRadius to
            // x = topCornerRadius + bottomCornerRadius. Net residual into the
            // host frame is whatever exceeds the chrome's horizontal pre-pad.
            let leadingH = max(0, (topCornerRadius + bottomCornerRadius) - leadingPrePad)
            let trailingH = max(0, (topCornerRadius + bottomCornerRadius) - trailingPrePad)
            return NookContentInsets(top: topV, bottom: bottomV, leading: leadingH, trailing: trailingH)
        case .floating:
            // `NookView.floatingExpandedRadius` uses `bottomCornerRadius` for
            // every corner. The chrome's horizontal pre-pad still uses
            // `topCornerRadius` (the `.padding(.horizontal, topCornerRadius)`
            // on the inner ZStack is form-agnostic).
            let r = bottomCornerRadius
            let topV = max(0, r - topPrePad)
            let bottomV = max(0, r - bottomPrePad)
            let leadingH = max(0, r - leadingPrePad)
            let trailingH = max(0, r - trailingPrePad)
            return NookContentInsets(top: topV, bottom: bottomV, leading: leadingH, trailing: trailingH)
        }
    }

    /// Subtract a wrapper's own padding from each axis and floor at zero. Used
    /// by a wrapper view (e.g. `NookExpandedView`) to re-inject insets that are
    /// relative to its inner content frame rather than its outer frame.
    public func reducingBy(_ padding: CGFloat) -> NookContentInsets {
        NookContentInsets(
            top: max(0, top - padding),
            bottom: max(0, bottom - padding),
            leading: max(0, leading - padding),
            trailing: max(0, trailing - padding)
        )
    }
}

private struct NookContentInsetsEnvironmentKey: EnvironmentKey {
    static let defaultValue: NookContentInsets = .zero
}

public extension EnvironmentValues {
    /// Safe-area insets derived from the chrome's curved panel geometry. See
    /// ``NookContentInsets`` for the semantics and usage pattern.
    var nookContentInsets: NookContentInsets {
        get { self[NookContentInsetsEnvironmentKey.self] }
        set { self[NookContentInsetsEnvironmentKey.self] = newValue }
    }
}
