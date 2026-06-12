// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import NookSurface
import SwiftUI

/// Topbar for the expanded notch.
///
/// Minimal by design: a tiny home cluster on the left (matched to right-side icon
/// weight), and the keep-open / gear glyphs on the right. The only chrome-level
/// toggle is between the home surface and settings — everything else belongs to
/// whatever home view a downstream fork plugs in.
struct NookTopBar: View {
    @ObservedObject var appState: AppState
    let chromeInteractionAccent: Color
    @Binding var isHomeIconHovered: Bool
    let toggleKeepOpen: () -> Void

    /// Host-configurable leading-cluster label and icon (see `NookConfiguration`).
    let leadingTitle: (AppState) -> String
    let leadingIcon: String?

    /// Whether the gear (and thus the Settings breadcrumb) is part of the bar. When
    /// `false` the gear is omitted; `viewMode` never reaches `.settings` so the
    /// breadcrumb is moot. See ``NookConfiguration/showsSettings``.
    let showsSettings: Bool

    /// Host actions for the trailing cluster, rendered left of the keep-open lock and
    /// gear. `nil` (the default) leaves the cluster as just the framework's lock/gear.
    /// See ``NookTopBarConfiguration/trailingItems``.
    let trailingItems: (@Sendable @MainActor () -> AnyView)?

    /// How the row spans the expanded content column. See ``NookTopBarConfiguration/Width``.
    let width: NookTopBarConfiguration.Width

    /// When non-`nil`, the leading cluster becomes a compact module switcher popup
    /// instead of the plain title - supplied by the multi-module router only when the
    /// host opted into ``NookModuleSwitcherPlacement/leadingCluster``. Defaults to `nil`,
    /// so single-module and menu-bar-switcher hosts render the plain title unchanged.
    /// See ``NookModuleSwitcher``.
    var moduleSwitcher: NookModuleSwitcher? = nil

    @Environment(\.nookResolvedTheme) private var resolvedTheme

    /// Curve-derived safe-area insets from the chrome. Leading/trailing clusters pad
    /// by these values so host rows and the top bar share one horizontal gutter.
    @Environment(\.nookContentInsets) private var contentInsets

    /// Host-overridable chrome strings, layout metrics, and in-panel motion (see
    /// ``NookChromeLabels`` / ``NookChromeMetrics`` / ``NookChromeMotion``). Injected by
    /// ``NookExpandedView``; default reproduces today's chrome.
    @Environment(\.nookChromeLabels) private var labels
    @Environment(\.nookChromeMetrics) private var metrics
    @Environment(\.nookChromeMotion) private var motion

    /// Host branding — used for the leading-cluster brand mark when no `leadingIcon` is
    /// configured. Injected by the expanded router. See ``NookHostBranding``.
    @Environment(\.nookHostBranding) private var branding

    var body: some View {
        Group {
            switch width {
            case .contentColumn:
                contentColumnBar
            case .intrinsic:
                intrinsicBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: metrics.topBarHeight)
        .animation(motion.breadcrumb, value: appState.moduleBreadcrumb)
    }

    /// Full-width bar: trailing cluster is overlay-pinned so it always shares the
    /// content-column gutter with host rows (Settings toggles, home command bars).
    private var contentColumnBar: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .leading) {
                leadingBarContent
            }
            .overlay(alignment: .trailing) {
                trailingCluster
                    .padding(.trailing, contentInsets.trailing)
            }
            .frame(maxWidth: .infinity, minHeight: metrics.topBarHeight, maxHeight: metrics.topBarHeight)
    }

    private var intrinsicBar: some View {
        HStack(spacing: 8) {
            leadingBarContent
            Spacer(minLength: 0)
            trailingCluster
                .padding(.trailing, contentInsets.trailing)
        }
    }

    private var leadingBarContent: some View {
        HStack(spacing: 8) {
            homeLeadingCluster
                .fixedSize(horizontal: true, vertical: false)
                .padding(.leading, contentInsets.leading)

            if appState.isSettingsView {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(resolvedTheme.quaternaryLabel)

                Text(labels.settingsBreadcrumb)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(resolvedTheme.secondaryLabel)
            } else if let breadcrumb = appState.moduleBreadcrumb, !breadcrumb.isEmpty {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(resolvedTheme.quaternaryLabel)

                Text(breadcrumb)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(resolvedTheme.secondaryLabel)
                    .lineLimit(1)
                    .frame(width: metrics.breadcrumbMaxWidth, alignment: .leading)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.5),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .help(breadcrumb)
                    .transition(.opacity.combined(with: .offset(x: -4)))
            }

            Spacer(minLength: 0)
        }
    }

    private var trailingCluster: some View {
        HStack(spacing: 4) {
            if let trailingItems {
                trailingItems()
            }

            HeaderIcon(
                systemName: appState.keepNookOpen ? "lock.fill" : "lock.open",
                isActive: appState.keepNookOpen,
                activeColor: chromeInteractionAccent,
                help: labels.keepOpenHelp
            ) {
                toggleKeepOpen()
            }

            if showsSettings {
                HeaderIcon(
                    systemName: "gearshape",
                    isActive: appState.isSettingsView,
                    activeColor: chromeInteractionAccent,
                    help: labels.settingsHelp
                ) {
                    withAnimation(motion.viewModeChange) {
                        if appState.isSettingsView {
                            appState.showHome()
                        } else {
                            appState.showSettings()
                        }
                    }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// On home the configured title stays visible next to its icon; in settings —
    /// or when a module has pushed a `moduleBreadcrumb` (a drilled-in product
    /// sub-context) — the label collapses until the user hovers the glyph, which
    /// doubles as the back control. Clicking it exits Settings or clears the
    /// breadcrumb; the module observes that clear and pops its own sub-state.
    private var homeLeadingCluster: some View {
        let hasBreadcrumb = (appState.moduleBreadcrumb?.isEmpty == false)
        let showPersistentHomeTitle = appState.isHomeView && !appState.isSettingsView && !hasBreadcrumb
        let title = leadingTitle(appState)

        return HStack(spacing: 6) {
            if showPersistentHomeTitle, let moduleSwitcher {
                // Multi-module host that opted into an in-surface switcher: the leading
                // cluster IS the switcher (it replaces the plain title - no extra band,
                // no duplicated identity).
                ModuleSwitcherMenu(
                    switcher: moduleSwitcher,
                    fallbackIcon: leadingIcon,
                    fallbackTitle: title,
                    theme: resolvedTheme,
                    branding: branding
                )
            } else if showPersistentHomeTitle {
                if let leadingIcon {
                    StaticHeaderIcon(systemName: leadingIcon)
                } else {
                    branding.markView(
                        size: 11,
                        strokeWidth: 1.1,
                        color: resolvedTheme.secondaryLabel.opacity(0.92)
                    )
                    .frame(width: 11, height: 11)
                }
                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(resolvedTheme.secondaryLabel)
                    .lineLimit(1)
            } else {
                HeaderIcon(
                    systemName: leadingIcon ?? "chevron.left",
                    isActive: false,
                    activeColor: chromeInteractionAccent,
                    help: title
                ) {
                    withAnimation(motion.leadingClusterBack) {
                        if appState.isSettingsView {
                            appState.showHome()
                        } else if hasBreadcrumb {
                            appState.moduleBreadcrumb = nil
                        } else {
                            appState.showHome()
                        }
                    }
                }
                .accessibilityLabel(title)
                .onHover { isHomeIconHovered = $0 }

                if isHomeIconHovered {
                    Text(title)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(resolvedTheme.secondaryLabel)
                        .lineLimit(1)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .offset(x: -6)),
                                removal: .opacity.combined(with: .offset(x: -4))
                            )
                        )
                }
            }
        }
        .animation(motion.leadingClusterHover, value: isHomeIconHovered)
    }
}

/// The opt-in in-surface module switcher: a flat popup folded into the top bar's leading
/// cluster. Its label is the active module's icon + name (matching the plain-title chrome
/// it replaces) plus a small chevron; the menu lists every module, checks the active one,
/// and badges any that asked for attention. Shown only when a host opts into
/// ``NookModuleSwitcherPlacement/leadingCluster``. See ``NookModuleSwitcher``.
private struct ModuleSwitcherMenu: View {
    let switcher: NookModuleSwitcher
    let fallbackIcon: String?
    let fallbackTitle: String
    let theme: NookResolvedTheme
    let branding: NookHostBranding

    var body: some View {
        Menu {
            ForEach(switcher.modules) { descriptor in
                Button {
                    switcher.switchTo(descriptor.id)
                } label: {
                    if descriptor.id == switcher.activeID {
                        Label(descriptor.displayName, systemImage: "checkmark")
                    } else if switcher.attentionIDs.contains(descriptor.id) {
                        Label("\(descriptor.displayName)  •", systemImage: descriptor.icon)
                    } else {
                        Label(descriptor.displayName, systemImage: descriptor.icon)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                icon
                Text(activeTitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(theme.secondaryLabel)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(theme.tertiaryLabel)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Switch module")
    }

    private var activeTitle: String {
        switcher.activeDescriptor?.displayName ?? fallbackTitle
    }

    @ViewBuilder private var icon: some View {
        if let symbol = switcher.activeDescriptor?.icon ?? fallbackIcon {
            StaticHeaderIcon(systemName: symbol)
        } else {
            branding.markView(
                size: 11,
                strokeWidth: 1.1,
                color: theme.secondaryLabel.opacity(0.92)
            )
            .frame(width: 11, height: 11)
        }
    }
}
