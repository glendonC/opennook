// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

// ShelfNook — a file shelf in the notch, from the NookComponents add-on.
//
// Drag files onto the notch and they collect in the shelf; drag them back out to
// Finder or another app. The shelf persists across launches. Run with
// `swift run ShelfNook`, press ⌥⌘; to expand, then drag a file onto the notch.

import NookApp
import NookComponents
import SwiftUI

// `NookApp.main { … }` builds the configuration on the main actor, so the
// main-actor-isolated ShelfStore can be constructed here.
NookApp.main {
    // One shelf model, shared between the home view that renders it and the drop
    // handler that fills it.
    let shelf = ShelfStore()

    var configuration = NookConfiguration()
    configuration.setHome { ShelfHome(store: shelf) }
    // `NookConfiguration.onFileDrop` is typed `@Sendable @MainActor ([URL]) -> Bool`
    // — the closure runs on the main actor, so it can call `ShelfStore.accept`
    // directly without any `assumeIsolated` hop.
    configuration.onFileDrop = { urls in shelf.accept(urls) }
    return configuration
}

/// The shelf, with click-to-import folded into its drop zone via the host's
/// ``NookFilePicker`` — the picker-driven counterpart to drag-and-drop, in one surface.
///
/// Picker caveat: `swift run` produces an unbundled, unsandboxed binary with no
/// powerbox, so the open panel cannot enter TCC-protected folders (Downloads, etc.).
/// Build and run the signed `Nook.app` (the `NookHostApp` Xcode target) to exercise the
/// picker for real — see the Shipping checklist in README.md.
private struct ShelfHome: View {
    let store: ShelfStore
    @Environment(\.appServices) private var services

    var body: some View {
        NookShelfView(store: store, onImport: importFiles)
            .padding(.horizontal, 8)
    }

    private func importFiles() {
        // The host-provided picker handles app activation (so the panel is interactive
        // despite the non-activating notch panel) and holds the surface expanded for the
        // panel's lifetime.
        let picker = services.resolve(NookFilePickerKey.self)
        Task {
            guard let selection = await picker.open(.init(allowsMultipleSelection: true)) else {
                return
            }
            // Capture the shelf's security-scoped bookmarks while the picker's scoped
            // access is still live.
            selection.withAccess { urls in _ = store.accept(urls) }
        }
    }
}
