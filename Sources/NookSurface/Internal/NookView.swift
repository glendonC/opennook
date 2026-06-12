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
    @State private var trackedExpandedSize: CGSize = .zero
    @State private var ambientColor: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(nook: Nook<Expanded, CompactLeading, CompactTrailing>) {
        self.nook = nook
    }

    /// Safe-area strip the chrome reserves around the host's expanded content. Host-
    /// configurable per edge via ``NookStyle/expandedContentInsets``; the default
    /// reproduces the historical fixed geometry (0 top, 8 elsewhere).
    private var expandedContentInsets: NookEdgeInsets {
        nook.style.expandedContentInsets
    }

    /// `true` when the surface should render the free-floating panel instead of the
    /// notch-fused shape — a display with no notch, or a forced `.floating` presentation.
    private var isFloating: Bool {
        nook.layoutForm == .floating
    }

    /// Residual safe-area insets the host's expanded view can read via
    /// ``EnvironmentValues/nookContentInsets``. `.zero` while compact or hidden —
    /// no host expanded content is rendered in those states. The expanded value
    /// is the geometric clearance left over after the chrome's own paddings;
    /// see ``NookContentInsets/expanded(form:topCornerRadius:bottomCornerRadius:chromeSafeAreaInset:)``.
    private var contentInsets: NookContentInsets {
        guard nook.state == .expanded else { return .zero }
        return NookContentInsets.expanded(
            form: nook.layoutForm,
            topCornerRadius: nook.style.topCornerRadius,
            bottomCornerRadius: nook.style.bottomCornerRadius,
            chromeSafeAreaInsets: expandedContentInsets
        )
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
            case .liquidGlass(let glass):
                liquidGlassBackdrop(glass)
            }
        }
    }

    /// Liquid Glass backdrop. Apple's real glass material on macOS 26 Tahoe and later;
    /// a layered approximation on earlier systems. Both shape the glass to the same
    /// ``NookShape`` the chrome already clips to, so the rim and the eared/floating
    /// outline stay in register.
    @ViewBuilder
    private func liquidGlassBackdrop(_ glass: NookBackdrop.LiquidGlass) -> some View {
        // `Glass` / `.glassEffect` exist only in the macOS 26 SDK (Xcode 26+, Swift 6.2).
        // `@available` is a runtime gate and still needs those symbols present in the SDK
        // being compiled against, so an older Xcode cannot build the real path at all.
        // Gate it at compile time too: an older toolchain uses the approximation
        // unconditionally, while the macOS 26 SDK keeps the real material (runtime-gated
        // to macOS 26). This lets a consumer on an earlier Xcode still build the package.
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            realLiquidGlass(glass)
        } else {
            approximateLiquidGlass(glass)
        }
        #else
        approximateLiquidGlass(glass)
        #endif
    }

    #if compiler(>=6.2)
    @available(macOS 26.0, *)
    @ViewBuilder
    private func realLiquidGlass(_ glass: NookBackdrop.LiquidGlass) -> some View {
        let tinted: Glass = {
            guard let tint = glass.tint, glass.tintStrength > 0 else { return .regular }
            return Glass.regular.tint(tint.opacity(glass.tintStrength))
        }()
        Color.clear
            .glassEffect(tinted, in: notchShape)
            // The legibility pass is whatever the spec carries — the surface adds no
            // darken of its own on top of Apple's self-contrasting material.
            .overlay { glassShading(glass) }
    }
    #endif

    /// The host-supplied legibility shading, rendered as a gradient. `nil` shading draws
    /// nothing, leaving the glass pristine. The gradient, its stops, and its direction all
    /// come from the ``NookBackdrop/LiquidGlass`` spec — the surface never substitutes its
    /// own, so a host can shape the falloff however it likes.
    @ViewBuilder
    private func glassShading(_ glass: NookBackdrop.LiquidGlass) -> some View {
        if let shading = glass.shading {
            LinearGradient(
                gradient: shading.gradient,
                startPoint: shading.startPoint,
                endPoint: shading.endPoint
            )
        }
    }

    /// Pre-Tahoe approximation: a glassy material, an optional tint, a legibility darken,
    /// then the specular treatment that actually reads as "glass" — a top-down sheen and
    /// a bright rim traced along ``notchShape``. The outer `.clipShape` trims the rim's
    /// outer half, leaving an inner highlight along the edge.
    @ViewBuilder
    private func approximateLiquidGlass(_ glass: NookBackdrop.LiquidGlass) -> some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

            if let tint = glass.tint, glass.tintStrength > 0 {
                tint.opacity(glass.tintStrength)
            }

            glassShading(glass)

            if glass.highlightStrength > 0 {
                LinearGradient(
                    colors: [Color.white.opacity(0.16 * glass.highlightStrength), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
                notchShape
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5 * glass.highlightStrength),
                                Color.white.opacity(0.06 * glass.highlightStrength)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
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
        // The `@State` `compactLeadingWidth`/`compactTrailingWidth` retain their last
        // measured value when the slot views disappear (SwiftUI doesn't fire
        // `onGeometryChange` for a vanishing view), but the values are only consulted
        // while the slots are present, so the stale carry-over is benign.
    }

    private func expandedContent() -> some View {
        HStack(spacing: 0) {
            if nook.state == .expanded {
                nook.expandedContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.nookContentInsets, contentInsets)
                    .transition(.blur(intensity: 6).combined(with: .scale(y: 0.72, anchor: .top)).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: expandedContentInsets.top) }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: expandedContentInsets.bottom) }
        .safeAreaInset(edge: .leading, spacing: 0) { Color.clear.frame(width: expandedContentInsets.leading) }
        .safeAreaInset(edge: .trailing, spacing: 0) { Color.clear.frame(width: expandedContentInsets.trailing) }
        .background {
            if let ambientColor {
                NookAmbientColorBackground(color: ambientColor)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: ambientColor)
        .onPreferenceChange(NookAmbientColorPreferenceKey.self) { ambientColor = $0 }
        .frame(minWidth: isFloating ? 0 : nook.notchSize.width)
        .onGeometryChange(for: CGSize.self, of: \.size) { size in
            guard nook.state == .expanded, size != trackedExpandedSize else { return }
            trackedExpandedSize = size
            nook.noteExpandedContentSizeChange()
        }
    }
}
