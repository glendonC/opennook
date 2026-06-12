// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// Internal helpers used by the chrome's expand/collapse transitions.
struct BlurModifier: ViewModifier {
    let intensity: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: intensity)
    }
}

struct ScaleModifier: ViewModifier {
    let xScale: CGFloat
    var yScale: CGFloat
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content.scaleEffect(x: xScale, y: yScale, anchor: anchor)
    }
}

extension AnyTransition {
    static func blur(intensity: CGFloat) -> AnyTransition {
        .modifier(
            active: BlurModifier(intensity: intensity),
            identity: BlurModifier(intensity: 0)
        )
    }

    static func scale(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> AnyTransition {
        .modifier(
            active: ScaleModifier(xScale: x, yScale: y, anchor: anchor),
            identity: ScaleModifier(xScale: 1, yScale: 1, anchor: anchor)
        )
    }
}
