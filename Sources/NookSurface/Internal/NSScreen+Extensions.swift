// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

extension NSScreen {
    /// Heuristic - Apple notched displays expose auxiliary widths on both sides of the camera.
    var hasNotch: Bool {
        auxiliaryTopLeftArea?.width != nil && auxiliaryTopRightArea?.width != nil
    }

    /// Width-between-aux-areas / safe-area-top, when the screen actually has a notch.
    var notchSize: NSSize? {
        guard
            let topLeftPadding = auxiliaryTopLeftArea?.width,
            let topRightPadding = auxiliaryTopRightArea?.width
        else {
            return nil
        }

        let height = safeAreaInsets.top
        let width = frame.width - topLeftPadding - topRightPadding
        return NSSize(width: width, height: height)
    }

    /// Frame the chrome should hug. Centered horizontally, anchored to the top of the screen.
    var notchFrame: NSRect? {
        guard let notchSize else { return nil }
        return NSRect(
            x: frame.midX - (notchSize.width / 2),
            y: frame.maxY - notchSize.height,
            width: notchSize.width,
            height: notchSize.height
        )
    }

    var menubarHeight: CGFloat {
        frame.maxY - visibleFrame.maxY
    }

    /// Use `notchFrame` when available; otherwise center an arbitrary-width box at the top.
    /// Lets the surface still render reasonably on non-notched displays during testing.
    var notchFrameWithMenubarAsBackup: NSRect {
        if let notchFrame {
            return notchFrame
        }

        let arbitraryWidth: CGFloat = 300
        return NSRect(
            x: frame.midX - (arbitraryWidth / 2),
            y: frame.maxY - menubarHeight,
            width: arbitraryWidth,
            height: menubarHeight
        )
    }
}
