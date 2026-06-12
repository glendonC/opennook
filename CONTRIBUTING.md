# Contributing to OpenNook

Thanks for the interest. OpenNook is a small, opinionated framework - most
contributions land faster when scoped against the roadmap or an existing
issue, so for anything larger than a typo or a one-file fix, **open an issue
first** to align on approach.

## Local setup

```sh
swift build         # build everything (libraries + examples)
swift test          # run the test suite
swift run Nook      # launch the demo
```

For a real `.app` bundle (signing, Cmd-R in Xcode):

```sh
brew install xcodegen
./Scripts/regenerate-xcodeproj.sh
open Nook.xcodeproj
```

`Nook.xcodeproj` is a generated artifact - `project.yml` is the source of
truth. Both build paths compile the same SwiftPM modules; behavior cannot
drift between them.

## Project layout

- `Sources/NookSurface/` - the notch window engine. **MIT-licensed** (forked
  from [DynamicNotchKit](https://github.com/MrKai77/DynamicNotchKit)). Keep
  this layer thin - no app/product logic.
- `Sources/NookKit/` - app chrome: lifecycle, state, settings, hotkey.
  Apache-2.0.
- `Sources/NookApp/` + `NookExecutable/` + `App/` - minimal demo app and
  launch trampolines.
- `Sources/NookComponents/` - opt-in add-ons (file shelf, activity queue,
  volume glyph). Apache-2.0.
- `Examples/` - single-file demonstrations of the public API. Each example
  is one `main.swift` showing one concept.
- `Tests/` - `NookKitTests` and `NookComponentsTests`.

## License headers

CI enforces an SPDX header on every Swift file:

- Files under `Sources/NookSurface/` (and the two `@testable`-importing test
  files) must carry `SPDX-License-Identifier: MIT`.
- Every other Swift file must carry `SPDX-License-Identifier: Apache-2.0`.

See `.github/workflows/ci.yml` for the exact rule. If you add files, copy
the header from a neighboring file in the same module.

## Coding conventions

- **Strict concurrency.** Every target opts into `StrictConcurrency` via
  `Package.swift`. New code must compile clean under the strict checker - no
  silenced warnings, no `@unchecked Sendable` without a written reason.
- **MainActor where it belongs.** UI types, the coordinator, and anything
  touching `NSApp`/`NSWindow` are `@MainActor`. Components that only model
  data (`ShelfStore`) are not.
- **Public API discipline.** A new public symbol is a permanent commitment.
  Prefer `internal` first; promote to `public` only when a host needs it.
  When you do go public, add a DocC comment.
- **Tests.** Anything non-trivial needs coverage. Tests run with
  `swift test --parallel` in CI.
- **No new dependencies** without discussion. The framework currently has
  zero runtime third-party dependencies - keep it that way unless there's a
  strong reason.

## Examples

`Examples/*` are how developers learn the API - they're the README's
companion, not a dumping ground. Each example demonstrates **one** concept
and uses **only the public API** (no `@testable`, no module-internal
reaches). If a concept needs a new example, propose it in an issue.

## Documentation

The docs site lives in `site/src/content/docs/` (Astro Starlight, MDX). When you
add or change public API, update the docs in the same change:

- Add or update the relevant guide under `site/src/content/docs/guides/`, and
  wire any new page into the sidebar in `site/astro.config.mjs`.
- Add a `CHANGELOG.md` entry under `## [Unreleased]`.
- Keep prose ASCII-only - hyphens (` - `), straight quotes, three dots for an
  ellipsis - and match the surrounding guides' style.
- A new public symbol still needs its DocC comment in source (see Public API
  discipline above); the guides are the prose layer on top.

The symbol-level API reference is generated from those DocC comments by Swift
Package Index (`.spi.yml`), not hand-written. Preview it locally with
`./Scripts/generate-docs.sh`; CI builds it on every PR, so a doc comment that
breaks DocC fails the build before it reaches the next release.

Treat a feature as unfinished until its docs land. The site lagging the code is
the failure mode this section exists to prevent.

## Submitting a change

1. Branch off `main` (don't commit on `main` directly).
2. Make the change. Run `swift build && swift test` locally.
3. If you added or changed public API, add a `CHANGELOG.md` entry and update
   the docs site (see [Documentation](#documentation)).
4. If you touched `Sources/NookSurface/` or added/removed Swift files,
   verify the license-header job locally:
   `grep -L 'SPDX-License-Identifier' $(find Sources Tests Examples App -name '*.swift')`
   should print nothing.
5. Open a PR using the template. CI must be green before review.

## License

By contributing, you agree that your contributions are licensed under the
license that applies to the file you're editing (MIT for `NookSurface/`,
Apache-2.0 elsewhere). See [`LICENSE`](LICENSE),
[`LICENSE-MIT-NOOKSURFACE`](LICENSE-MIT-NOOKSURFACE), and [`NOTICE.md`](NOTICE.md).
