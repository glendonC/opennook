// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation
import UniformTypeIdentifiers

/// One file parked on the notch shelf.
///
/// Persists a **bookmark**, not a raw path, so a shelved file survives being moved or
/// renamed between launches. `resolveURL()` turns the bookmark back into a live URL;
/// it returns `nil` only when the file genuinely can't be reached.
///
/// The bookmark is created **security-scoped** when possible, so a sandboxed host (which
/// only gets file access via the user's drop) can re-derive the file on a later launch.
/// In a non-sandboxed host the security scope is simply inert. `bookmark` is
/// deliberately opaque `Data` so the strategy can evolve without an API break.
///
/// Under the App Sandbox, *touching the file's contents* — not just resolving the
/// bookmark — requires bracketing the access with
/// `startAccessingSecurityScopedResource()`/`stopAccessingSecurityScopedResource()`.
/// Use ``withResolvedURL(_:)`` for any synchronous read; it does the bracketing.
/// `resolveURL()` is for path-level use only (display, comparison) and does **not**
/// start access. Outbound drag of file *contents* into a sandboxed or promise-only
/// drop target is a v1 limitation — it needs file promises (see ``NookShelfView``).
public struct ShelfItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    /// File name without extension — what the chip label shows.
    public let displayName: String
    public let fileExtension: String
    public let addedAt: Date
    /// Bookmark data resolving back to the file. Opaque by design.
    public let bookmark: Data
    /// `UTType` identifier, for the outbound drag pasteboard.
    public let typeIdentifier: String

    /// Builds an item from a file URL, capturing a bookmark. Returns `nil` if the URL
    /// can't be bookmarked (e.g. it doesn't exist).
    public static func make(from url: URL) -> ShelfItem? {
        guard let bookmark = Self.bookmarkData(for: url) else { return nil }
        let type = UTType(filenameExtension: url.pathExtension)?.identifier
            ?? UTType.data.identifier
        return ShelfItem(
            id: UUID(),
            displayName: url.deletingPathExtension().lastPathComponent,
            fileExtension: url.pathExtension,
            addedAt: Date(),
            bookmark: bookmark,
            typeIdentifier: type
        )
    }

    /// Resolves the bookmark to a current URL, or `nil` if the file can no longer be
    /// reached. A `nil` here is **not** proof the file was deleted — under the App
    /// Sandbox it can also mean access was lost — so callers must not treat it as a
    /// deletion signal (see ``ShelfStore/purgeMissing()``).
    ///
    /// This does **not** start security-scoped access. It is for path-level use
    /// (display, comparison) only; to read the file's contents use
    /// ``withResolvedURL(_:)``.
    public func resolveURL() -> URL? {
        resolved()?.url
    }

    /// Resolves the bookmark and runs `body` with security-scoped access active for the
    /// call's duration — started before `body`, stopped after (a no-op for plain
    /// bookmarks and non-sandboxed hosts). Returns `nil`, without calling `body`, if the
    /// bookmark can't be resolved.
    ///
    /// Use this for any *synchronous* file read (icon, attributes, contents). It is not
    /// suitable for work that outlives the call — e.g. an asynchronous drag session —
    /// because access stops as soon as `body` returns.
    public func withResolvedURL<T>(_ body: (URL) -> T) -> T? {
        guard let url = resolved()?.url else { return nil }
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        return body(url)
    }

    /// Resolves the bookmark, also reporting whether the bookmark has gone stale and
    /// should be re-created from the returned URL.
    func resolved() -> (url: URL, isStale: Bool)? {
        // Try a security-scoped resolution first; fall back to a plain one for bookmarks
        // captured before security scoping (or in contexts where it isn't available).
        for options in [BookmarkResolutionOptions.securityScoped, BookmarkResolutionOptions.plain] {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return (url, isStale)
            }
        }
        return nil
    }

    /// Returns a copy whose bookmark has been re-captured from its current location, or
    /// `nil` if it can't currently be resolved. Used to heal a stale bookmark.
    func refreshedBookmark() -> ShelfItem? {
        guard let url = resolveURL(), let fresh = Self.bookmarkData(for: url) else {
            return nil
        }
        return ShelfItem(
            id: id,
            displayName: displayName,
            fileExtension: fileExtension,
            addedAt: addedAt,
            bookmark: fresh,
            typeIdentifier: typeIdentifier
        )
    }

    /// Captures bookmark data for `url`, preferring a security-scoped bookmark and
    /// falling back to a plain one (security-scoped creation throws when the process
    /// holds no scoped access to the file, e.g. some non-sandboxed contexts).
    private static func bookmarkData(for url: URL) -> Data? {
        if let scoped = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return scoped
        }
        return try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}

/// Bookmark-resolution option sets, tried in order by ``ShelfItem/resolved()``.
private enum BookmarkResolutionOptions {
    static let securityScoped: URL.BookmarkResolutionOptions = [.withSecurityScope]
    static let plain: URL.BookmarkResolutionOptions = []
}
