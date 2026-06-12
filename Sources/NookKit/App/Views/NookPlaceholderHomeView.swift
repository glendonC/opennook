// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// The default home surface - a placeholder shown until a host app registers its own.
///
/// This is what `NookConfiguration` installs when no `home` content is supplied. To
/// replace it, register your own view: `NookApp.main { MyHomeView() }`, or set
/// ``NookConfiguration/setHome(_:)``. No need to fork the framework.
///
/// It reads the resolved palette from the `\.nookResolvedTheme` environment value, which
/// the expanded surface injects - host home views should do the same so they track the
/// configured theme automatically.
public struct NookPlaceholderHomeView: View {
    @Environment(\.nookResolvedTheme) private var theme

    public init() {}

    public var body: some View {
        VStack(spacing: 10) {
            NookMarkView(
                size: 28,
                strokeWidth: 2,
                color: theme.secondaryLabel
            )
            Text("Nook")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.primaryLabel)
            Text("Register your own view with NookConfiguration to start building.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(theme.tertiaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
