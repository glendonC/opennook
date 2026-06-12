// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// Severity of a transient ``NookStatus`` message - drives the banner's glyph so an
/// informational or success message reads differently from an error.
///
/// The framework chrome stays on its minimal palette (the glyph is tinted with the
/// resolved theme's accent rather than inventing semantic red/green/orange tokens); the
/// distinction is carried by the SF Symbol. A host that wants colored severity can supply
/// its own banner content or theme.
public enum NookStatusSeverity: String, Sendable, Equatable, CaseIterable {
    case error
    case warning
    case info
    case success

    /// SF Symbol shown to the left of the message for this severity.
    public var systemImage: String {
        switch self {
        case .error: "exclamationmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        }
    }
}

/// A short-lived status message surfaced in the top-bar banner, with a ``severity`` that
/// selects its glyph. See ``AppState/status`` and ``AppState/showStatus(_:severity:)``.
public struct NookStatus: Sendable, Equatable {
    public var message: String
    public var severity: NookStatusSeverity

    public init(message: String, severity: NookStatusSeverity = .error) {
        self.message = message
        self.severity = severity
    }
}
