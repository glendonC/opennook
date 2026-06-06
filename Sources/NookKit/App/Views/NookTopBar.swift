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

    @Environment(\.nookResolvedTheme) private var resolvedTheme

    /// Curve-derived safe-area insets from the chrome. The leading/trailing
    /// icon clusters pad themselves by these so the lock/gear glyphs don't sit
    /// right under the panel's top corner curvature when a host configures a
    /// larger ``NookStyle/topCornerRadius`` than the default.
    @Environment(\.nookContentInsets) private var contentInsets

    var body: some View {
        HStack(spacing: 8) {
            homeLeadingCluster
                .fixedSize(horizontal: true, vertical: false)
                .padding(.leading, contentInsets.leading)

            if appState.isSettingsView {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(resolvedTheme.quaternaryLabel)

                Text("Settings")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(resolvedTheme.secondaryLabel)
            } else if let breadcrumb = appState.moduleBreadcrumb, !breadcrumb.isEmpty {
                // Module-driven drill-down label (a selected deck, an open
                // document …). Renders with the same separator and typography
                // weight as Settings so the chrome stays visually consistent.
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(resolvedTheme.quaternaryLabel)

                // The chrome's top edge sits at the menu bar level by design,
                // so the topbar runs *under* the physical notch on a notched
                // display: anything horizontally between the notch's edges is
                // hardware-clipped. Leading content (home + chevron) lives on
                // the left of the notch, trailing icons live on the right;
                // the breadcrumb needs to stay on the leading side too or it
                // visually splits across the notch. `.frame(width:)` (a hard
                // size, not a flex) caps the breadcrumb to the leading
                // pre-notch region without propagating an intrinsic width up
                // through the chrome's sizing. The alpha mask fades the
                // trailing 16pt so SwiftUI's missing-ellipsis truncation reads
                // as a soft edge; `.help(breadcrumb)` exposes the full
                // string on hover for the truncated tail.
                Text(breadcrumb)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(resolvedTheme.secondaryLabel)
                    .lineLimit(1)
                    .frame(width: NookLayout.breadcrumbMaxWidth, alignment: .leading)
                    .mask(
                        // Full opacity for the leading half of the
                        // breadcrumb frame, then a smooth ramp to fully
                        // clear at the trailing edge. A 50% fade region
                        // is wide enough to land over actually-rendered
                        // characters even when SwiftUI truncates short of
                        // the frame's trailing edge — a narrower band
                        // mostly fades empty space and reads as crisp.
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

            HStack(spacing: 4) {
                HeaderIcon(
                    systemName: appState.keepNookOpen ? "lock.fill" : "lock.open",
                    isActive: appState.keepNookOpen,
                    activeColor: chromeInteractionAccent,
                    help: "Stay expanded after hover"
                ) {
                    toggleKeepOpen()
                }

                if showsSettings {
                    HeaderIcon(
                        systemName: "gearshape",
                        isActive: appState.isSettingsView,
                        activeColor: chromeInteractionAccent,
                        help: "Settings"
                    ) {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
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
            .padding(.trailing, contentInsets.trailing)
        }
        .frame(height: 24)
        .animation(.easeOut(duration: 0.18), value: appState.moduleBreadcrumb)
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
            if showPersistentHomeTitle {
                if let leadingIcon {
                    StaticHeaderIcon(systemName: leadingIcon)
                } else {
                    NookMarkView(
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
                // Deep view (Settings or a module breadcrumb): the cluster is
                // the back control. With no configured icon, a back chevron
                // keeps that affordance.
                HeaderIcon(
                    systemName: leadingIcon ?? "chevron.left",
                    isActive: false,
                    activeColor: chromeInteractionAccent,
                    help: title
                ) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.85)) {
                        if appState.isSettingsView {
                            appState.showHome()
                        } else if hasBreadcrumb {
                            // Module sub-context: clear the breadcrumb and let
                            // the module react to that (by exiting its own
                            // drilled-in state).
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
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isHomeIconHovered)
    }
}
