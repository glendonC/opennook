# Changelog

All notable changes to OpenNook are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `NookResolvedTheme.accent` - the interactive tint for chrome controls (lock,
  gear, focus rings, surface tint, feedback cues). Defaults to the macOS system
  accent, so existing palettes are unchanged; set it to brand the chrome.
- `NookResolvedTheme.fontDesign` - restyles the chrome's own typography (top
  bar, compact pill, default home placeholder). Defaults to `.default`.
- `NookConfiguration.style` - host override for the chrome corner radii.
- `NookConfiguration.transitions` - host override for the expand / collapse /
  convert animation curves.
- `NookConfiguration.expandedWidth` - host override for the expanded surface
  width.
- `NookConfiguration.setSettings(_:)` / `settings` - inject a custom Settings
  surface in place of the built-in one (still reached via the gear).
- `NookScreenLocator.resolveIndex(preference:displays:mainIndex:)` and
  `DisplayCandidate` - the multi-display fallback policy as a pure function, now
  unit-tested without a live `NSScreen`.
- CI: an Xcode-version matrix (`latest-stable` required, `latest` non-blocking)
  and a guard so the license-header check can't pass vacuously if the source
  layout moves.

### Changed

- `NookStyle.openingAnimation` / `closingAnimation` / `conversionAnimation` are
  now `public`.
- `NookLayout` and its metrics are now `public`.

### Fixed

- One-shot peripheral feedback cues now auto-clear when finished. Previously the
  overlay's `TimelineView` kept ticking at 60fps forever after a cue (rendering
  only `Color.clear`); the cold-launch greeting shimmer armed this on every
  launch.
- README: corrected the persistence-prefix guidance - NookKit writes under
  `opennook.*`, not `nook.*` (only the file shelf uses `nook.shelf.*`).

## [0.2.0] - 2026-05-23

See the [v0.2.0 release](https://github.com/glendonC/opennook/releases) on
GitHub.

## [0.1.0] - 2026-05-22

Initial public release. See the
[v0.1.0 release](https://github.com/glendonC/opennook/releases) on GitHub.

[Unreleased]: https://github.com/glendonC/opennook/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/glendonC/opennook/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/glendonC/opennook/releases/tag/v0.1.0
