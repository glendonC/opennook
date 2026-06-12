// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

// SPM trampoline. `swift run Nook` builds this target and immediately
// hands off to the shared library entry point in `NookApp`. The Xcode app
// target uses `App/main.swift`, which is identical - both keep behavior in one
// place so the headless dev loop and the bundled-app launch can never diverge.
//
// Note: the SPM-built binary has no `Contents/Info.plist` on disk, so it runs
// without bundle metadata. Use `xcodebuild` / Cmd-R in Xcode when you need the
// real `.app` bundle (signing, notarization); `swift run` is the fastest path
// for everyday iteration.

import NookApp

NookApp.main()
