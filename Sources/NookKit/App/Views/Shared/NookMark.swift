// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// The OpenNook brand mark - a minimal notch arc. Pair with a center dot in
/// ``NookMarkView``; matches `site/public/nook-mark.svg`.
public struct NookMark: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let origin = CGPoint(
            x: rect.midX - 12 * scale,
            y: rect.midY - 12 * scale
        )

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }

        var path = Path()
        path.move(to: point(5, 10.5))
        path.addCurve(
            to: point(19, 10.5),
            control1: point(8.1, 4.5),
            control2: point(15.9, 4.5)
        )
        return path
    }
}

/// Renders ``NookMark`` as a stroked arc plus filled dot.
public struct NookMarkView: View {
    public var size: CGFloat
    public var strokeWidth: CGFloat
    public var color: Color

    public init(size: CGFloat = 24, strokeWidth: CGFloat = 1.75, color: Color = .primary) {
        self.size = size
        self.strokeWidth = strokeWidth
        self.color = color
    }

    public var body: some View {
        ZStack {
            NookMark()
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            Circle()
                .fill(color)
                .frame(width: size * (4 / 24), height: size * (4 / 24))
                .position(x: size / 2, y: size * (16 / 24))
        }
        .frame(width: size, height: size)
    }
}

#if canImport(AppKit)
import AppKit

public extension NookMarkView {
    /// Renders the mark into a template `NSImage` for menu-bar and other AppKit chrome.
    @MainActor
    static func makeTemplateImage(size: CGFloat = 16, color: Color = .primary) -> NSImage? {
        let renderer = ImageRenderer(
            content: NookMarkView(size: size, strokeWidth: max(1, size * (1.75 / 24)), color: color)
        )
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }
}
#endif
