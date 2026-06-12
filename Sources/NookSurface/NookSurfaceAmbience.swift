// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin

import SwiftUI

/// A SwiftUI preference that lets *any* expanded content propagate a single ambient color
/// up to the surface backdrop.
///
/// This is a product-agnostic presentation seam: the engine knows nothing about *why* a
/// color was chosen or *which* view chose it. Content sets the preference (directly with
/// `.preference(key:value:)`, or via a layer that wraps it); the surface reads it and
/// paints a soft wash behind the whole expanded chrome, including edge and safe-area
/// padding, so the wash is not clipped to the content's own bounds.
///
/// When several views in the content tree set a value, the last non-nil value wins.
public struct NookAmbientColorPreferenceKey: PreferenceKey {
    public static var defaultValue: Color? { nil }

    public static func reduce(value: inout Color?, nextValue: () -> Color?) {
        value = nextValue() ?? value
    }
}

/// A top-to-bottom wash rendered behind expanded surface content when a `NookAmbientColorPreferenceKey`
/// value is present. Purely decorative and non-interactive - the engine draws it but does
/// not interpret it.
public struct NookAmbientColorBackground: View {
    let color: Color

    public init(color: Color) {
        self.color = color
    }

    public var body: some View {
        LinearGradient(
            colors: [
                color.opacity(0.34),
                color.opacity(0.16),
                color.opacity(0.06),
                color.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

public extension View {
    /// Propagates an ambient color up to the surface backdrop via
    /// ``NookAmbientColorPreferenceKey``. Pass `nil` to contribute nothing.
    ///
    /// This is the generic seam. Product layers may wrap it to attach their own
    /// semantics (e.g. "the home screen's theme color").
    func nookAmbientColor(_ color: Color?) -> some View {
        preference(key: NookAmbientColorPreferenceKey.self, value: color)
    }
}
