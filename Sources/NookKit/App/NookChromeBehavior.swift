// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookSurface
import SwiftUI

/// Host-process-global *chrome behavior* knobs that the framework otherwise hardcodes:
/// hover side-effects, the cold-launch greeting, and how appearance preferences map to
/// the surface backdrop.
///
/// These are distinct from ``NookConfiguration``'s per-surface content/theme seams —
/// they describe how the single shared notch surface *behaves*, so they live at the
/// host-process level (``NookHostConfiguration/chromeBehavior``). The single-module path
/// mirrors them on ``NookConfiguration/chromeBehavior`` and forwards onto the synthesized
/// host. The default value reproduces today's framework behavior exactly.
///
/// `Sendable`: assembled at a `main.swift`'s nonisolated top level and handed to
/// `NookApp.main`, which crosses to the main actor — like the configurations that carry
/// it. Not `Equatable` because ``backdrop`` carries a closure.
public struct NookChromeBehavior: Sendable {
    /// Resolves the surface backdrop from the live appearance state. Returns the
    /// `NSVisualEffectView` material / darken / solid fill the chrome paints behind its
    /// content. Receives the current ``NookAppearancePreferences``, the effective
    /// `ColorScheme` (after the host's palette override + the system scheme), and whether
    /// the system's Reduce Transparency is on.
    ///
    /// `@Sendable @MainActor`: invoked during the main-actor backdrop sync and carried by
    /// a `Sendable` `NookChromeBehavior`.
    public typealias BackdropResolver =
        @Sendable @MainActor (NookAppearancePreferences, ColorScheme, Bool) -> NookBackdrop

    /// Side-effects to apply while the cursor is over the chrome. Defaults to `[]` (the
    /// framework default — neither hover-keep-visible nor hover haptics). Set to
    /// ``NookHoverBehavior/all`` (or a subset) to opt in. Read once when the surface is
    /// built, like ``NookConfiguration/style``.
    public var hoverBehavior: NookHoverBehavior

    /// Whether the one-shot perimeter shimmer plays at cold launch. Defaults to `true`
    /// (today's greeting). Set to `false` for a silent launch — the chrome still settles
    /// into its compact launch state, it just skips the feedback flourish.
    public var showsLaunchShimmer: Bool

    /// Overrides how appearance preferences map to the surface backdrop. `nil` (the
    /// default) uses the framework mapping (``NookBackdropMapping/notchBackdrop(preferences:effectiveColorScheme:reduceTransparency:)``):
    /// solid black/white for `.solid` or Reduce Transparency, otherwise a `.sidebar`
    /// vibrancy with a legibility darken pass. Supply a resolver to paint a brand-specific
    /// material, darken, or solid color while still reacting to the live appearance state.
    public var backdrop: BackdropResolver?

    public init(
        hoverBehavior: NookHoverBehavior = [],
        showsLaunchShimmer: Bool = true,
        backdrop: BackdropResolver? = nil
    ) {
        self.hoverBehavior = hoverBehavior
        self.showsLaunchShimmer = showsLaunchShimmer
        self.backdrop = backdrop
    }

    /// The framework defaults — what ships when a host sets no chrome behavior. Using
    /// this reproduces today's behavior exactly.
    public static let `default` = NookChromeBehavior()
}
