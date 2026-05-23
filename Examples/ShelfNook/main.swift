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
    configuration.setHome { NookShelfView(store: shelf) }
    // `NookConfiguration.onFileDrop` is typed `@Sendable @MainActor ([URL]) -> Bool`
    // — the closure runs on the main actor, so it can call `ShelfStore.accept`
    // directly without any `assumeIsolated` hop.
    configuration.onFileDrop = { urls in shelf.accept(urls) }
    return configuration
}
