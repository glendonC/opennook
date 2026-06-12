# Scripts

Developer scripts. All are simple wrappers around `swift` / `xcodegen`; none
are required to build or run the app.

- `apply-license-headers.sh` - stamp the SPDX/Apache-2.0 header on new files.
- `dev-run.sh` - `swift run Nook` with the right env. Headless
  iteration; no `Info.plist`, so URL-scheme dispatch does NOT work in this
  build. Use Cmd-R in Xcode for the bundled `.app`.
- `watch-run.sh` - auto-rebuild on file change for tight UI iteration.
- `regenerate-xcodeproj.sh` - rebuilds `Nook.xcodeproj` from
  `project.yml` (source of truth). Run after editing `project.yml`, or after
  a fresh clone before opening in Xcode the first time. Requires `xcodegen`
  (`brew install xcodegen`).

## Two build paths, one codebase

Both paths compile from the same SPM library targets. Pick the one that fits
the iteration:

| Path  | Command                                                              | When                                                          | Limitations                                                              |
| ----- | -------------------------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------ |
| SPM   | `swift run Nook` (or `Scripts/dev-run.sh`)                    | Fast headless iteration                                       | No `Info.plist` on disk -> Launch Services can't route URL-scheme links   |
| Xcode | Cmd-R in `Nook.xcodeproj` or `xcodebuild -scheme NookHostApp build` | End-to-end (signing, notarization, bundled `.app`)        | Slower first build; `DerivedData/` lives in `.build/xcode/`              |

`swift test` runs the test suite from the package root. Both paths share the
same module artifacts via SwiftPM, so behavior cannot drift.
