// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import AppKit
import NookKit
import SwiftUI

/// The file-shelf surface. Register it as a host home view — either as the whole home
/// view (`NookApp.main { NookShelfView(store: shelf) }`) or as one section of a larger
/// `home` content closure.
///
/// Files dropped on the notch appear here once the host wires ``ShelfStore/accept(_:)``
/// into `NookConfiguration.onFileDrop`. Each shelved file can be dragged back out to
/// Finder or another app via a file-promise drag source — which works from the notch's
/// non-activating panel, satisfies receivers that demand file promises, and brackets
/// security-scoped access for sandboxed reads.
public struct NookShelfView: View {
    @ObservedObject private var store: ShelfStore
    @Environment(\.nookResolvedTheme) private var theme

    /// Optional "add files" action. When provided, the empty drop zone becomes
    /// click-to-import and a `+` button appears in the populated header, so picking
    /// files lives in the same surface as drag-and-drop. The host supplies the action
    /// (typically the `NookFilePicker`), keeping this view agnostic about where files
    /// come from - the same stance as `NookConfiguration.onFileDrop`.
    private let onImport: (() -> Void)?

    public init(store: ShelfStore, onImport: (() -> Void)? = nil) {
        self.store = store
        self.onImport = onImport
    }

    public var body: some View {
        VStack(spacing: 8) {
            if store.items.isEmpty {
                emptyState
            } else {
                header
                shelfRow
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var emptyState: some View {
        // The dashed zone is both a drop target and, when an import action is wired, a
        // click target - one affordance, mirroring a web "drop or browse" upload well.
        if let onImport {
            Button(action: onImport) { dropZone }
                .buttonStyle(.plain)
                .help("Drop files here, or click to import")
        } else {
            dropZone
        }
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(theme.tertiaryLabel)
            Text(onImport == nil ? "Drop files onto the notch to shelve them" : "Drop files here, or click to import")
                .font(.system(size: 11))
                .foregroundStyle(theme.tertiaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.subtleStroke, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("^[\(store.items.count) file](inflect: true)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondaryLabel)
            Spacer(minLength: 0)
            if let onImport {
                Button(action: onImport) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.tertiaryLabel)
                .help("Import files")
            }
            Button("Clear") { store.clear() }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(theme.tertiaryLabel)
        }
    }

    private var shelfRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.items) { item in
                    ShelfItemChip(item: item, theme: theme) {
                        store.remove(item)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// One file on the shelf: icon, name, drag-out, and a hover-revealed remove control.
private struct ShelfItemChip: View {
    let item: ShelfItem
    let theme: NookResolvedTheme
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            icon
            Text(item.displayName)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(theme.secondaryLabel)
        }
        .frame(width: 72)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.subtleFill)
        )
        .overlay(alignment: .topTrailing) {
            if isHovered {
                removeButton
            }
        }
        .onHover { isHovered = $0 }
        // The provider registers a *promise*: the file copy runs only when the
        // receiver requests data, with security scope held around it. See
        // `makeShelfDragItemProvider` for why this shape is needed (non-activating
        // panel, promise-only receivers, sandbox scope). `ShelfItem` is Sendable, so
        // the closure can capture by value without lifetime ceremony.
        .onDrag { makeShelfDragItemProvider(for: item) }
        .help(item.displayName + (item.fileExtension.isEmpty ? "" : ".\(item.fileExtension)"))
    }

    @ViewBuilder
    private var icon: some View {
        // `withResolvedURL` brackets security-scoped access for the icon fetch so it
        // works under the App Sandbox, where a bare resolved URL grants no access.
        if let fileIcon = item.withResolvedURL({ NSWorkspace.shared.icon(forFile: $0.path) }) {
            Image(nsImage: fileIcon)
                .resizable()
                .frame(width: 34, height: 34)
        } else {
            Image(systemName: "questionmark.square.dashed")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(theme.tertiaryLabel)
                .frame(width: 34, height: 34)
        }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(theme.secondaryLabel)
                .background(Circle().fill(theme.subtleFill))
        }
        .buttonStyle(.plain)
        .help("Remove from shelf")
        .offset(x: 5, y: -5)
    }
}
