// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

// VolumeNook — an ambient volume glyph in the compact pill (NookComponents).
//
// SystemVolumeObserver tracks the default output device via public CoreAudio APIs;
// NookVolumeIndicator renders the level as a compact-slot glyph. Run with
// `swift run VolumeNook`, leave the nook collapsed, and change the volume — the glyph
// to the right of the notch updates. It shows the level; it does not replace Apple's
// volume HUD.

import NookApp
import NookComponents
import SwiftUI

// One observer, rendered in the compact-trailing slot.
let volume = SystemVolumeObserver()

var configuration = NookConfiguration()
configuration.setCompactTrailing { NookVolumeIndicator(observer: volume) }
NookApp.main(configuration)
