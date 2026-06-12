// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the MIT License.
// See /LICENSE-MIT-NOOKSURFACE for the modifications license.

import AppKit
import SwiftUI

/// What the chrome paints behind compact and expanded nook content.
///
/// Three intentionally disjoint cases:
///
/// - ``vibrancy(_:)`` paints an `NSVisualEffectView` material with an optional darken
///   pass on top — the default frosted look, used when translucency is allowed.
/// - ``solid(_:)`` paints a flat opaque fill — used for `.solid` chrome styles and
///   whenever Reduce Transparency is on, where `NSVisualEffectView` is avoided.
/// - ``liquidGlass(_:)`` paints Apple's Liquid Glass material (macOS 26+), falling back
///   to a layered material-plus-specular-rim approximation on earlier systems.
///
/// These are *modes*, not flags. A caller picks one and supplies only the parameters
/// that mode needs — no more eleven-field configuration struct where half the fields
/// are dead per branch.
///
/// Extending to e.g. `.gradient(Gradient)` later is one new case and one new view
/// branch; existing callers keep compiling.
public enum NookBackdrop: Equatable, Sendable {
    /// Frosted vibrancy: a system material with an optional black overlay for
    /// legibility on bright wallpapers.
    case vibrancy(Vibrancy)

    /// Flat opaque fill. Use this for `.solid` chrome styles and when Reduce
    /// Transparency is on — it avoids `NSVisualEffectView` entirely.
    case solid(Color)

    /// Liquid Glass: the macOS 26 Tahoe glass material when available, an approximation
    /// (a glassy `NSVisualEffectView` material with a tint pass, legibility darken, and
    /// a specular rim + top sheen) on macOS 15-25. See ``LiquidGlass`` for the knobs.
    case liquidGlass(LiquidGlass)

    /// Vibrancy parameters: which material to render, how to blend it against the
    /// content below the window, and how much darken to composite over it.
    public struct Vibrancy: Equatable, Sendable {
        /// The `NSVisualEffectView.Material` to render. `.sidebar` is the
        /// framework default; it matches Apple's translucent chrome conventions.
        public var material: NSVisualEffectView.Material

        /// `.behindWindow` (the default) samples the desktop wallpaper through the
        /// nook window. `.withinWindow` samples sibling content within the window.
        public var blendingMode: NSVisualEffectView.BlendingMode

        /// 0...1 black overlay composited on top of the material for legibility.
        /// 0 disables the darken pass entirely.
        public var darkenOpacity: CGFloat

        public init(
            material: NSVisualEffectView.Material = .sidebar,
            blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
            darkenOpacity: CGFloat = 0
        ) {
            self.material = material
            self.blendingMode = blendingMode
            self.darkenOpacity = darkenOpacity
        }
    }

    /// Liquid Glass parameters. The same knobs drive both render paths: on macOS 26+
    /// they configure Apple's real glass material; on macOS 15-25 they drive the
    /// layered approximation. A host can build one directly and return it from a
    /// ``NookChromeBehavior`` backdrop resolver to paint brand-tinted glass — that
    /// closure, not this struct, is where the "more customizable than off-the-shelf"
    /// flexibility lives.
    public struct LiquidGlass: Equatable, Sendable {
        /// Optional color pushed through the glass. `nil` (the default) is neutral,
        /// clear glass that simply refracts the wallpaper.
        public var tint: Color?

        /// 0...1 strength of the ``tint``. Ignored when `tint` is `nil`. On macOS 26+
        /// this becomes the alpha of the glass's tint color; on the approximation it is
        /// the opacity of the tint overlay.
        public var tintStrength: CGFloat

        /// 0...1 intensity of the specular rim and top sheen that sell the glass read on
        /// pre-Tahoe systems. macOS 26+ supplies its own edge highlights, so this only
        /// adds a faint extra rim there.
        public var highlightStrength: CGFloat

        /// Legibility pass composited under chrome content, expressed as a gradient the
        /// caller fully owns — flat, bottom-weighted, top-weighted, banded, multi-stop,
        /// any direction, any color. `nil` leaves the glass pristine. The surface renders
        /// exactly this and imposes nothing of its own, so a coder building on OpenNook is
        /// never boxed into the framework's idea of the gradient; the framework's default
        /// mapping just supplies a sensible one (a top-to-bottom darken so the surface
        /// reads glassier near the wallpaper) that a host can replace wholesale.
        public var shading: Shading?

        public init(
            tint: Color? = nil,
            tintStrength: CGFloat = 0.18,
            highlightStrength: CGFloat = 0.6,
            shading: Shading? = nil
        ) {
            self.tint = tint
            self.tintStrength = tintStrength
            self.highlightStrength = highlightStrength
            self.shading = shading
        }

        /// A shading pass: a `Gradient` plus the direction it runs across the surface.
        /// Build one directly for full control, or use ``uniform(_:)`` for a flat fill.
        /// Because it carries a whole gradient, a host can shape the glass any way it
        /// likes without the framework constraining it to a single knob.
        public struct Shading: Equatable, Sendable {
            /// The gradient painted over the glass. Its stops and colors are entirely the
            /// caller's; the framework never rewrites them.
            public var gradient: Gradient

            /// Where the gradient begins. Defaults to the top edge.
            public var startPoint: UnitPoint

            /// Where the gradient ends. Defaults to the bottom edge — so a two-stop
            /// gradient runs top-to-bottom, the common "glassier toward the bottom" case.
            public var endPoint: UnitPoint

            public init(
                gradient: Gradient,
                startPoint: UnitPoint = .top,
                endPoint: UnitPoint = .bottom
            ) {
                self.gradient = gradient
                self.startPoint = startPoint
                self.endPoint = endPoint
            }

            /// A flat, uniform shading of one color — no gradient falloff.
            public static func uniform(_ color: Color) -> Shading {
                Shading(gradient: Gradient(colors: [color, color]))
            }
        }
    }

    /// The default backdrop — a pure black solid, matching the menu-bar notch chrome
    /// when no other treatment is wanted. Equivalent to the historical
    /// `NookBackdropConfiguration.solidBlack`; rendering is byte-identical.
    public static let solidBlack = NookBackdrop.solid(.black)
}
