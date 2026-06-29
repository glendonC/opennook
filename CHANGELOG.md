# Changelog

All notable changes to OpenNook are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims
to follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-06-29

### Added

- `NookChromeTypography` - a host-tunable token type for the framework's own
  fonts. Set via `NookConfiguration.typography`; defaults reproduce the framework
  exactly, and the resolved `fontDesign` still cascades over the roles. Restyles
  framework text without forking, the typography counterpart to the existing color
  (`NookResolvedTheme`) and layout (`NookChromeMetrics`) seams. Roles cover the
  top bar, compact pill, and status banner, plus the placeholder home, the
  built-in Settings panel, and the optional `NookComponents` add-ons.
- `NookChromeMetrics` gained the element-level dimensions, corner radii, spacing,
  and emphasis-opacity values that were previously baked into the framework views -
  the chrome (header icons, leading brand mark, compact pill, status banner), the
  placeholder home, the Settings panel (rows, pickers, the shortcut key cap, the
  accent swatches, the disclosure section), and the `NookComponents` shelf,
  activity card, and volume glyph. All new fields default to today's values, so
  the change is additive and non-breaking.

### Changed

- The framework views now read every font, size, radius, spacing, and opacity from
  `NookChromeTypography` / `NookChromeMetrics` instead of inline literals - the
  chrome (top bar, header icons, compact pill, status banner), the placeholder
  home, the built-in Settings panel, and the `NookComponents` add-ons. No visual
  change at the defaults; a host can now restyle any of these surfaces through
  public API only. (A few intentionally-structural literals stay inline: motion
  spring/offset magnitudes, the breadcrumb gradient mask, the fixed severity and
  destructive-action colors, and zero-floor spacers.)
- The GitHub repository moved to [athledev-labs/opennook](https://github.com/athledev-labs/opennook).
  Update your Swift package URL; GitHub redirects the old `glendonC/opennook` path
  for a transition period.

## [0.3.1] - 2026-06-12

### Fixed

- The Liquid Glass surface style now builds on Xcode versions earlier than 26.
  Its `Glass` / `.glassEffect` use (the macOS 26 SDK) is compile-gated behind
  `#if compiler(>=6.2)`, so an earlier toolchain compiles the pre-Tahoe
  approximation instead of failing with "cannot find 'Glass' in scope"; on
  macOS 26 the real material is still used at runtime.
- Cleared a Swift 6 concurrency warning on `NookFilePickerKey.defaultValue` (a
  `@MainActor`-isolated value held in a nonisolated static): the inert default
  picker now has a `nonisolated init`. No behavior change.

## [0.3.0] - 2026-06-12

The chrome-customization release. v0.3.0 opens up the framework chrome through
additive, non-breaking seams - every default still reproduces the demo exactly,
so hosts opt in only where they need to. It also adds a Liquid Glass surface
style, a chrome-derived safe-area for host content, and the module drill-in
breadcrumb. This is the surface downstream hosts have been depending on from
`main`; pin to `0.3.0` instead.

This is still 0.x: the public API is not frozen. Pin to a tag.

### Added

- Liquid Glass surface style - the real macOS 26 `glassEffect` material with a
  layered pre-Tahoe approximation fallback, gated on availability so it cannot
  crash on older systems. Host-configurable like the other surface styles.
- `NookContentInsets` / `NookEdgeInsets` - a chrome-derived safe-area so host
  content can align to the same horizontal edge as the top bar instead of
  double-padding. The per-edge expanded-content inset is configurable.
- `AppState.moduleBreadcrumb` - a drill-in breadcrumb on the host top bar for
  multi-module hosts, with an overflow fade mask constrained to the pre-notch
  region.
- `NookHostConfiguration.moduleSwitcherPlacement` / `NookModuleSwitcherPlacement`
  - choose where a multi-module host surfaces its switcher: `.menuBar` (the
  default - a "Modules" section in the menu-bar item), `.leadingCluster` (a
  compact popup folded into the top bar's leading cluster), or `.none` (cycle /
  per-module hotkeys only). The framework no longer plants switcher chrome in a
  module's expanded surface uninvited.
- `NookConfiguration.style` - host override for the chrome corner radii.
- `NookConfiguration.transitions` - host override for the expand / collapse /
  convert animation curves.
- `NookConfiguration.expandedWidth` and a host-configurable top-bar width mode
  (`.contentColumn`) - control the expanded surface width and keep the top bar
  aligned to the content column.
- `NookConfiguration.setSettings(_:)` / `settings` - inject a custom Settings
  surface in place of the built-in one (still reached via the gear).
- `setTopBarTrailingItems` - host actions placed left of the lock / gear.
- `NookChromeBehavior` - host control over hover side-effects, the cold-launch
  shimmer, and the appearance-to-backdrop mapping.
- `NookChromeLabels`, `NookChromeMetrics`, `NookChromeMotion`, and host status
  severity - localize chrome strings, tune the fixed layout values, retune the
  in-panel springs, and post info / success / warning / error banners.
- `NookPreferenceDefaults` - host-seeded launch defaults for appearance, global
  hotkey, and display target. Seed-only: a value the user changes in Settings
  always wins, and the seed is never persisted.
- `NookHostBranding` brand mark and `NookMarkView` - drop in a custom mark that
  replaces the OpenNook glyph in the top bar, About card, and menu bar; unify
  host identity across the chrome and the menu-bar item.
- `NookAccentPreset` / `accentPreset`, `NookResolvedTheme.accent`, and
  `NookResolvedTheme.fontDesign` - brand the interactive chrome tint and restyle
  the chrome's own typography. Defaults are unchanged.
- `NookAppearanceSettingsSection` - embed the framework's appearance controls
  inside a host-supplied Settings surface.
- Host file picker (`filePicker`) for modules, with file import folded into the
  shelf.
- `AppState` exposed to host-registered home and compact content.
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
- The Settings UI was reworked alongside the expanded chrome-customization
  seams.
- The module switcher is no longer a chrome band at the top of the expanded
  surface. A multi-module host now switches from a "Modules" menu-bar section
  and the cycle / per-module hotkeys by default, leaving the surface entirely
  the module's own; opt into a compact in-surface switcher with
  `NookHostConfiguration.moduleSwitcherPlacement = .leadingCluster`.

### Fixed

- One-shot peripheral feedback cues now auto-clear when finished. Previously the
  overlay's `TimelineView` kept ticking at 60fps forever after a cue (rendering
  only `Color.clear`); the cold-launch greeting shimmer armed this on every
  launch.
- The nook no longer collapses accidentally after an in-surface layout change.
- Top-bar trailing icons now align to the row edge - the cluster is expanded
  before horizontal padding is applied, on a full-width row.
- The breadcrumb fade is constrained to the pre-notch region.
- README: corrected the persistence-prefix guidance - NookKit writes under
  `opennook.*`, not `nook.*` (only the file shelf uses `nook.shelf.*`).
- Layout-grace tests are stable under parallel CI load.

### Docs

- Added a `ChromeNook` example demonstrating the chrome-customization seams.
- Fleshed out guides for theming, multiple modules, the file shelf, the
  activity queue, and the volume glyph.
- Refreshed the README and added an LLM-friendly markdown export of the docs.

## [0.2.0] - 2026-05-23

See the [v0.2.0 release](https://github.com/athledev-labs/opennook/releases) on
GitHub.

## [0.1.0] - 2026-05-22

Initial public release. See the
[v0.1.0 release](https://github.com/athledev-labs/opennook/releases) on GitHub.

[Unreleased]: https://github.com/athledev-labs/opennook/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/athledev-labs/opennook/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/athledev-labs/opennook/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/athledev-labs/opennook/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/athledev-labs/opennook/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/athledev-labs/opennook/releases/tag/v0.1.0
