// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim — DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin — OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// The notch chrome itself: arches around the menu-bar notch, switches between expanded and
/// compact-with-side-slots, and paints the configured backdrop behind both.
struct NookView<Expanded, CompactLeading, CompactTrailing>: View
where Expanded: View, CompactLeading: View, CompactTrailing: View {
    @ObservedObject private var nook: Nook<Expanded, CompactLeading, CompactTrailing>
    @State private var compactLeadingWidth: CGFloat = 0
    @State private var compactTrailingWidth: CGFloat = 0
    @State private var ambientColor: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let safeAreaInset: CGFloat = 8

    init(nook: Nook<Expanded, CompactLeading, CompactTrailing>) {
        self.nook = nook
    }

    /// `true` when the surface should render the free-floating panel instead of the
    /// notch-fused shape — a display with no notch, or a forced `.floating` presentation.
    private var isFloating: Bool {
        nook.layoutForm == .floating
    }

    private var expandedCornerRadii: (top: CGFloat, bottom: CGFloat) {
        (top: nook.style.topCornerRadius, bottom: nook.style.bottomCornerRadius)
    }

    private var compactCornerRadii: (top: CGFloat, bottom: CGFloat) {
        (top: 6, bottom: 14)
    }

    /// Floating panels use convex corners — a card when expanded, a capsule when
    /// compact (radius = half the pill height). No notch ears to fuse, so the same
    /// radius applies to all four corners.
    private var floatingExpandedRadius: CGFloat { expandedCornerRadii.bottom }
    private var floatingCompactRadius: CGFloat { max(nook.notchSize.height / 2, 8) }

    /// Vertical gap that drops the floating panel clear of the menu bar. Zero in notch
    /// mode, where the chrome is meant to sit flush against the top edge.
    private var floatingTopInset: CGFloat {
        isFloating ? nook.menubarHeight + 8 : 0
    }

    private var minWidth: CGFloat {
        // A floating panel is purely content-driven; only the notch shape needs a
        // minimum (the notch gap plus its ears).
        isFloating ? 0 : nook.notchSize.width + (topCornerRadius * 2)
    }

    private var topCornerRadius: CGFloat {
        if isFloating {
            return nook.state == .expanded ? floatingExpandedRadius : floatingCompactRadius
        }
        return nook.state == .expanded ? expandedCornerRadii.top : compactCornerRadii.top
    }

    private var bottomCornerRadius: CGFloat {
        if isFloating {
            return nook.state == .expanded ? floatingExpandedRadius : floatingCompactRadius
        }
        return nook.state == .expanded ? expandedCornerRadii.bottom : compactCornerRadii.bottom
    }

    /// In compact mode, slot-width asymmetry shifts the whole shape so the gap stays centered on the notch.
    private var xOffset: CGFloat {
        nook.state == .compact ? compactXOffset : 0
    }

    /// Notch mode re-centers the shape on the physical notch when the leading/trailing
    /// slots differ in width. A floating pill has no notch to center on, so it stays put.
    private var compactXOffset: CGFloat {
        isFloating ? 0 : (compactTrailingWidth - compactLeadingWidth) / 2
    }

    /// Backdrop sits behind chrome content, both flattened into a single layer, then clipped
    /// to the animatable notch shape. Compositing as one group means the spring animation can
    /// scale content + backdrop atomically — no magic overshoot padding required to plug
    /// edge gaps mid-bounce.
    ///
    /// The matching `.contentShape(NookShape)` is critical: `.clipShape` only clips drawing,
    /// not hit-testing. Without it, the hover region falls back to the rectangular bounds —
    /// which extend down into the would-be-expanded area because the expanded content's
    /// `.fixedSize()` doesn't actually collapse to 0×0 when wrapped in a max-frame. Result:
    /// hovering in the empty space below a compact nook triggers the hover-grow animation.
    /// Hit-testing the same `NookShape` we render confines hover to the visible chrome.
    var body: some View {
        notchContent()
            .background { notchBackdrop() }
            .overlay { feedbackOverlay() }
            .compositingGroup()
            .clipShape(notchShape)
            .contentShape(notchShape)
            .onHover(perform: nook.updateHoverState)
            .offset(x: xOffset)
            // Floating mode drops the panel below the menu bar; notch mode keeps it
            // flush to the top edge (inset 0). Applied outside the clipped chrome so it
            // shifts the whole shape without distorting it or the hover region.
            .padding(.top, floatingTopInset)
            .animation(nook.effectiveConversionAnimation, value: nook.state)
            .animation(nook.effectiveConversionAnimation, value: [compactLeadingWidth, compactTrailingWidth])
    }

    /// Peripheral cue overlay. Sits above backdrop+content but inside the compositing group,
    /// so the shimmer stroke flattens with the chrome before the notch shape carves the visible
    /// region — no edge gaps mid-bounce, no spillover beyond the arch.
    private func feedbackOverlay() -> some View {
        NookFeedbackOverlay(
            event: nook.feedbackEvent,
            form: nook.layoutForm,
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius,
            reduceMotion: reduceMotion
        )
    }

    private var notchShape: NookShape {
        NookShape(
            form: nook.layoutForm,
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        )
    }

    private func notchBackdrop() -> some View {
        Group {
            switch nook.backdrop {
            case .vibrancy(let spec):
                ZStack {
                    VisualEffectView(
                        material: spec.material,
                        blendingMode: spec.blendingMode
                    )
                    if spec.darkenOpacity > 0 {
                        Color.black.opacity(spec.darkenOpacity)
                    }
                }
            case .solid(let color):
                color
            }
        }
    }

    private func notchContent() -> some View {
        ZStack {
            compactContent()
                .fixedSize()
                .offset(x: nook.state == .compact ? 0 : compactXOffset)
                .frame(
                    // Notch mode reserves the notch width while expanded so the
                    // collapsed slots line up; a floating pill is content-driven.
                    width: (nook.state == .compact || isFloating) ? nil : nook.notchSize.width,
                    height: (nook.state == .compact && nook.isHovering) ? nook.menubarHeight : nook.notchSize.height
                )

            expandedContent()
                .fixedSize()
                .frame(
                    maxWidth: nook.state == .expanded ? nil : 0,
                    maxHeight: nook.state == .expanded ? nil : 0
                )
                .offset(x: nook.state == .compact ? -compactXOffset : 0)
        }
        .padding(.horizontal, topCornerRadius)
        .fixedSize()
        .frame(minWidth: minWidth, minHeight: nook.notchSize.height)
    }

    private func compactContent() -> some View {
        HStack(spacing: 0) {
            if nook.state == .compact, !nook.disableCompactLeading {
                nook.compactLeadingContent
                    .safeAreaInset(edge: .leading, spacing: 0) { Color.clear.frame(width: 8) }
                    .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 4) }
                    .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 8) }
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) { compactLeadingWidth = $0 }
                    .transition(.blur(intensity: 6).combined(with: .scale(x: 0, anchor: .trailing)).combined(with: .opacity))
            }

            // Notch mode: a gap exactly the notch width, so the leading/trailing slots
            // straddle the physical notch. Floating mode: no notch — just a small gap
            // keeping the two slots from touching inside the pill.
            Spacer()
                .frame(width: isFloating ? 8 : nook.notchSize.width)

            if nook.state == .compact, !nook.disableCompactTrailing {
                nook.compactTrailingContent
                    .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: 8) }
                    .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 4) }
                    .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 8) }
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) { compactTrailingWidth = $0 }
                    .transition(.blur(intensity: 6).combined(with: .scale(x: 0, anchor: .leading)).combined(with: .opacity))
            }
        }
        .frame(height: nook.notchSize.height)
        // `disableCompactLeading/Trailing` are construction-time `let`s on `Nook` —
        // they cannot change at runtime, so no `.onChange` reconciliation is needed.
        // The compact widths are reset to 0 on the (hidden) transition path itself.
    }

    private func expandedContent() -> some View {
        HStack(spacing: 0) {
            if nook.state == .expanded {
                nook.expandedContent
                    .transition(.blur(intensity: 6).combined(with: .scale(y: 0.72, anchor: .top)).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 0) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: safeAreaInset) }
        .safeAreaInset(edge: .leading, spacing: 0) { Color.clear.frame(width: safeAreaInset) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: safeAreaInset) }
        .background {
            if let ambientColor {
                NookAmbientColorBackground(color: ambientColor)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: ambientColor)
        .onPreferenceChange(NookAmbientColorPreferenceKey.self) { ambientColor = $0 }
        .frame(minWidth: isFloating ? 0 : nook.notchSize.width)
    }
}
