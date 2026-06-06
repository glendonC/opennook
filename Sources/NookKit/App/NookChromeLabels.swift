// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Host-overridable strings the framework chrome renders — for localization or product
/// naming (e.g. "Preferences" instead of "Settings"). Defaults reproduce today's English.
///
/// Set via ``NookConfiguration/labels``. The values reach the top bar and the status
/// banner through the chrome environment (``EnvironmentValues/nookChromeLabels``).
public struct NookChromeLabels: Sendable, Equatable {
    /// The Settings breadcrumb shown after the leading cluster (`[icon] Title › Settings`).
    public var settingsBreadcrumb: String

    /// Tooltip on the keep-open lock glyph.
    public var keepOpenHelp: String

    /// Tooltip on the Settings gear glyph.
    public var settingsHelp: String

    /// Tooltip on the status banner's dismiss button.
    public var dismissHelp: String

    public init(
        settingsBreadcrumb: String = "Settings",
        keepOpenHelp: String = "Stay expanded after hover",
        settingsHelp: String = "Settings",
        dismissHelp: String = "Dismiss"
    ) {
        self.settingsBreadcrumb = settingsBreadcrumb
        self.keepOpenHelp = keepOpenHelp
        self.settingsHelp = settingsHelp
        self.dismissHelp = dismissHelp
    }

    /// The framework-default English strings.
    public static let `default` = NookChromeLabels()
}

private struct NookChromeLabelsKey: EnvironmentKey {
    static let defaultValue: NookChromeLabels = .default
}

public extension EnvironmentValues {
    /// Host-overridable chrome strings. See ``NookChromeLabels``.
    var nookChromeLabels: NookChromeLabels {
        get { self[NookChromeLabelsKey.self] }
        set { self[NookChromeLabelsKey.self] = newValue }
    }
}
