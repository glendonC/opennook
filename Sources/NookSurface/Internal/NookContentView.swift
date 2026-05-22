// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim — DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin — OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// Hosts the nook chrome inside the panel's content view.
struct NookContentView<Expanded, CompactLeading, CompactTrailing>: View
where Expanded: View, CompactLeading: View, CompactTrailing: View {
    @ObservedObject private var nook: Nook<Expanded, CompactLeading, CompactTrailing>

    init(nook: Nook<Expanded, CompactLeading, CompactTrailing>) {
        self.nook = nook
    }

    var body: some View {
        NookView(nook: nook)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(nook.effectiveConversionAnimation, value: nook.isHovering)
    }
}
