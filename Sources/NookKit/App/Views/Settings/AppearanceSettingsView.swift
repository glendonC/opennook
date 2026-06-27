// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookSurface
import SwiftUI

/// Theme + surface pickers for host Settings surfaces. Writes through ``AppState/replaceAppearancePreferences(_:)``.
public struct NookAppearanceSettingsSection: View {
    @ObservedObject public var appState: AppState
    @Environment(\.nookResolvedTheme) private var theme
    @Environment(\.nookChromeTypography) private var typography
    @Environment(\.nookChromeMetrics) private var metrics

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: metrics.settingsBlockSpacing) {
            labeledPicker(title: "Theme", accessibilityLabel: "Theme") {
                Picker("Theme", selection: chromePaletteBinding) {
                    Text("Match Mac").tag(NookChromePalette.followSystem)
                    Text("Dark").tag(NookChromePalette.dark)
                    Text("Light").tag(NookChromePalette.light)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: metrics.settingsFieldSpacing) {
                labeledPicker(title: "Surface", accessibilityLabel: "Chrome surface") {
                    Picker("Surface", selection: surfaceStyleBinding) {
                        Text("Solid").tag(NookSurfaceStyle.solid)
                        Text("Translucent").tag(NookSurfaceStyle.translucent)
                        Text("Liquid Glass").tag(NookSurfaceStyle.liquidGlass)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                }

                Text(surfaceStyleDescription)
                    .font(typography.settingsCaption)
                    .foregroundStyle(theme.tertiaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: metrics.settingsFieldSpacing) {
                labeledPicker(title: "Layout", accessibilityLabel: "Chrome layout") {
                    Picker("Layout", selection: presentationBinding) {
                        Text("Auto").tag(NookPresentation.auto)
                        Text("Notch").tag(NookPresentation.notch)
                        Text("Floating").tag(NookPresentation.floating)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.small)
                }

                Text(presentationDescription)
                    .font(typography.settingsCaption)
                    .foregroundStyle(theme.tertiaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: metrics.settingsFieldSpacing) {
                Text("Accent")
                    .font(typography.settingsFieldLabel)
                    .foregroundStyle(theme.secondaryLabel)
                HStack(spacing: metrics.settingsInlineSpacing) {
                    ForEach(NookAccentPreset.allCases) { preset in
                        Button {
                            var prefs = appState.appearancePreferences
                            prefs.accentPreset = preset
                            appState.replaceAppearancePreferences(prefs)
                        } label: {
                            Circle()
                                .fill(preset.color())
                                .frame(
                                    width: metrics.settingsAccentSwatchSize,
                                    height: metrics.settingsAccentSwatchSize
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            accentRingColor(for: preset),
                                            lineWidth: metrics.settingsAccentSwatchStrokeWidth
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(preset.displayName)
                    }
                }
            }

            if appState.appearancePreferences.surfaceStyle != .solid {
                VStack(alignment: .leading, spacing: metrics.settingsFieldSpacing) {
                    Text(strengthLabel)
                        .font(typography.settingsFieldLabel)
                        .foregroundStyle(theme.secondaryLabel)
                    Slider(value: backdropStrengthBinding, in: 0.35...1)
                        .controlSize(.small)
                        .accessibilityLabel(strengthLabel)
                    Text("Lower shows more wallpaper through the chrome.")
                        .font(typography.settingsCaption)
                        .foregroundStyle(theme.tertiaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var surfaceStyleDescription: String {
        switch surfaceStyleBinding.wrappedValue {
            case .solid:
                return "Solid paints the chrome the same color as the notch — true black on dark, true white on light."
            case .translucent:
                return "Translucent shows the wallpaper through a frosted material."
            case .liquidGlass:
                return "Liquid Glass refracts the wallpaper through Apple's glass material on macOS 26, "
                    + "with a frosted-glass fallback on earlier versions."
        }
    }

    private var strengthLabel: String {
        surfaceStyleBinding.wrappedValue == .liquidGlass ? "Glass strength" : "Translucency strength"
    }

    private var presentationDescription: String {
        switch presentationBinding.wrappedValue {
            case .auto:
                return "Auto uses the notch shape on a notched display and a floating panel on any other."
            case .notch:
                return "Notch always uses the notch shape, even on a display without one."
            case .floating:
                return "Floating always shows a free-standing panel below the menu bar."
        }
    }

    @ViewBuilder
    private func labeledPicker(
        title: String,
        accessibilityLabel: String,
        @ViewBuilder picker: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: metrics.settingsFieldSpacing) {
            Text(title)
                .font(typography.settingsFieldLabel)
                .foregroundStyle(theme.secondaryLabel)
            picker()
                .accessibilityLabel(accessibilityLabel)
        }
    }

    /// The selected accent swatch's ring color; clear for the unselected swatches.
    private func accentRingColor(for preset: NookAccentPreset) -> Color {
        appState.appearancePreferences.accentPreset == preset
            ? theme.primaryLabel.opacity(metrics.settingsAccentSwatchSelectedOpacity)
            : Color.clear
    }

    private var chromePaletteBinding: Binding<NookChromePalette> {
        Binding(
            get: { appState.appearancePreferences.chromePalette },
            set: { next in
                var prefs = appState.appearancePreferences
                prefs.chromePalette = next
                appState.replaceAppearancePreferences(prefs)
            }
        )
    }

    private var surfaceStyleBinding: Binding<NookSurfaceStyle> {
        Binding(
            get: { appState.appearancePreferences.surfaceStyle },
            set: { next in
                var prefs = appState.appearancePreferences
                prefs.surfaceStyle = next
                appState.replaceAppearancePreferences(prefs)
            }
        )
    }

    private var presentationBinding: Binding<NookPresentation> {
        Binding(
            get: { appState.appearancePreferences.presentation },
            set: { next in
                var prefs = appState.appearancePreferences
                prefs.presentation = next
                appState.replaceAppearancePreferences(prefs)
            }
        )
    }

    private var backdropStrengthBinding: Binding<Double> {
        Binding(
            get: { appState.appearancePreferences.backdropStrength },
            set: { next in
                var prefs = appState.appearancePreferences
                prefs.backdropStrength = min(max(next, 0.15), 1)
                appState.replaceAppearancePreferences(prefs)
            }
        )
    }
}
