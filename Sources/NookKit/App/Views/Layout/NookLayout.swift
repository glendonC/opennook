// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Layout constants for the **demo's** expanded notch surface.
///
/// The chrome itself (`NookSurface.NookView`) is content-driven — it measures whatever
/// view you hand it via `.fixedSize()` and sizes the panel to fit. `width` here is purely
/// the demo's own choice: a stable width so the panel doesn't resize when switching
/// between the home and settings surfaces. Building your own notch app, you set whatever
/// width your content needs — or drop the `.frame(width:)` entirely and let it size to
/// content. Nothing in the framework requires a fixed width.
public enum NookLayout {
    /// Default expanded-surface width, used when a host does not set
    /// ``NookConfiguration/expandedWidth``. Comfortable for the settings panels; notch apps
    /// commonly sit in the 500–650 pt range (boring.notch 640, NotchDrop 600).
    public static let width: CGFloat = 520
    public static let edgePadding: CGFloat = 8
    public static let compactSlotSize: CGFloat = 24

    /// Maximum width allowed for the topbar's module-breadcrumb label.
    ///
    /// The topbar runs at the menu-bar level on a notched display, so anything
    /// between the notch's edges is hardware-clipped. The breadcrumb is capped
    /// to the leading pre-notch region so it doesn't visually split across
    /// the notch. Sized for the default 520pt chrome with a ~200pt M-series
    /// notch, leaving room for the chevron and a few characters of headroom.
    public static let breadcrumbMaxWidth: CGFloat = 140
}
