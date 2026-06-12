// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

// Xcode app-target trampoline. Cmd-R / xcodebuild assembles a real `.app`
// bundle around this binary with `App/Info.plist`. Behaviour is identical
// to the SPM executable trampoline at `Sources/NookExecutable/main.swift`
// - both delegate to the shared library entry point in `NookApp`.

import NookApp

NookApp.main()
