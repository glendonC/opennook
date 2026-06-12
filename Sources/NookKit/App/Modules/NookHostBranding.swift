// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// A host brand mark - builds the mark view at a requested size and color. The framework
/// renders it in the top-bar leading cluster (when no `leadingIcon` is set), the About
/// card, and (as a template image) the menu-bar status item.
///
/// `@Sendable @MainActor`: builds a SwiftUI view during main-actor rendering, carried by
/// a `Sendable` ``NookHostBranding``.
public typealias NookBrandMark = @Sendable @MainActor (_ size: CGFloat, _ color: Color) -> AnyView

/// Host-level identity surfaced through the framework chrome.
///
/// Strings here name the *host product* (the `.app` the user installed), not any
/// individual module - they are how the chrome labels itself across the multi-module
/// host's shared surface. The About card reads ``hostName`` and ``hostTagline``; the
/// show/hide hotkey label and the menu-bar fallback read ``hostName``; the brand ``mark``
/// replaces the OpenNook glyph across the chrome.
///
/// A single-module host can set these on ``NookConfiguration/branding`` (forwarded onto
/// the synthesized host); multi-module hosts set ``NookHostConfiguration/branding``.
public struct NookHostBranding: Sendable, Equatable {
    /// Display name of the host product. Used in About, in the show/hide hotkey label
    /// ("Show \(hostName)"), and in the menu-bar fallback's "Show \(hostName)" / icon
    /// accessibility text.
    public var hostName: String

    /// One-line "about" tagline. `nil` falls back to the framework's stock line, which
    /// describes the host as built with OpenNook.
    public var hostTagline: String?

    /// Replaces the OpenNook ``NookMark`` glyph wherever the chrome renders the brand
    /// mark - the top-bar leading cluster (when ``NookTopBarConfiguration/leadingIcon`` is
    /// `nil`), the About card, and the menu-bar status icon. `nil` (the default) keeps the
    /// OpenNook mark. Not part of ``Equatable`` (a closure can't be compared) - two
    /// brandings are equal when their strings match.
    public var mark: NookBrandMark?

    public init(hostName: String = "Nook", hostTagline: String? = nil, mark: NookBrandMark? = nil) {
        self.hostName = hostName
        self.hostTagline = hostTagline
        self.mark = mark
    }

    /// Equality ignores ``mark`` (closures aren't comparable): two brandings are equal
    /// when their `hostName` and `hostTagline` match.
    public static func == (lhs: NookHostBranding, rhs: NookHostBranding) -> Bool {
        lhs.hostName == rhs.hostName && lhs.hostTagline == rhs.hostTagline
    }

    /// The single-module / unconfigured-host default. Reproduces the demo's strings
    /// exactly so `NookApp.main { ... }` is unchanged.
    public static let `default` = NookHostBranding()

    /// Builds the brand mark view at the given size/color - the host's ``mark`` if set,
    /// otherwise the framework ``NookMarkView`` at the supplied `strokeWidth`.
    @MainActor
    public func markView(size: CGFloat, strokeWidth: CGFloat, color: Color) -> AnyView {
        if let mark {
            return mark(size, color)
        }
        return AnyView(NookMarkView(size: size, strokeWidth: strokeWidth, color: color))
    }
}

#if canImport(AppKit)
import AppKit

public extension NookHostBranding {
    /// Renders the brand mark into a template `NSImage` for the menu-bar status item - 
    /// the host's ``mark`` if set, otherwise the framework mark.
    @MainActor
    func menuBarTemplateImage(size: CGFloat = 14) -> NSImage? {
        guard let mark else {
            return NookMarkView.makeTemplateImage(size: size)
        }
        let renderer = ImageRenderer(content: mark(size, .primary))
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }
}
#endif

private struct NookHostBrandingKey: EnvironmentKey {
    static let defaultValue: NookHostBranding = .default
}

public extension EnvironmentValues {
    /// Host branding (``NookHostBranding``) injected by the expanded router so any
    /// framework chrome view can read it from the environment instead of taking it
    /// through every init in the path.
    var nookHostBranding: NookHostBranding {
        get { self[NookHostBrandingKey.self] }
        set { self[NookHostBrandingKey.self] = newValue }
    }
}
