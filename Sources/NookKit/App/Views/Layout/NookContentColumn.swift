// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookSurface
import SwiftUI

public extension View {
    /// Pins a row to the expanded content column.
    ///
    /// In ``NookTopBarConfiguration/Width/contentColumn`` mode, ``NookExpandedView``
    /// applies the horizontal gutter once (top bar + home/settings). Host rows should
    /// only use this helper for **vertical** clearance (`top`, `includeBottomInset`) or
    /// when ``NookTopBarConfiguration/Width/intrinsic`` is active (full horizontal insets).
    func nookContentColumnRow(
        insets: NookContentInsets,
        alignment: Alignment = .leading,
        top: CGFloat = 0,
        includeBottomInset: Bool = false
    ) -> some View {
        padding(.leading, insets.leading)
            .padding(.trailing, insets.trailing)
            .padding(.top, top)
            .padding(.bottom, includeBottomInset ? insets.bottom : 0)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}
