# Security Policy

## Supported versions

OpenNook is pre-1.0. Security fixes land on `main` and the next tagged
release. Older tags are not patched.

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Use GitHub's private vulnerability reporting:
<https://github.com/athledev-labs/opennook/security/advisories/new>

Include:

- a description of the issue,
- a minimal reproduction or proof of concept,
- the affected version (commit SHA or tag),
- any disclosure timeline you have in mind.

You'll get an acknowledgement within a few days. Confirmed issues are fixed
on a private branch, released, and credited in the release notes (unless you
ask to stay anonymous).

## Scope notes

OpenNook is a macOS framework, not a service. The realistic risk surface:

- **NookSurface** runs an `NSPanel` with elevated window level - bugs here
  could affect window-layer behavior of the host app.
- **HotkeyController** uses Carbon's `RegisterEventHotKey`; mis-registered
  hotkeys can swallow keystrokes intended for other apps.
- **Shelf** persists scoped bookmarks. Bookmark-handling bugs could expose
  paths outside the intended sandbox scope.
- **No network code.** The framework makes no outbound connections.

Bugs in the demo app's signing / notarization configuration are not in
scope - those are a packaging concern per host.
