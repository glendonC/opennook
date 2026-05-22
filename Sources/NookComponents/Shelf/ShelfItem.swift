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
/// ``bookmarkKind`` records how the bookmark was captured. This matters under the App
/// Sandbox: a `.nonScoped` bookmark cannot resolve in a future sandboxed launch even
/// when the file is right there, so ``ShelfStore``'s purge rule preserves it instead
/// of silently corroding the shelf. Items persisted by older builds decode with
/// ``BookmarkKind/unknown`` and are treated like `.nonScoped` for purge purposes.
///
/// Under the App Sandbox, *touching the file's contents* — not just resolving the
/// bookmark — requires bracketing the access with
/// `startAccessingSecurityScopedResource()`/`stopAccessingSecurityScopedResource()`.
/// Use ``withResolvedURL(_:)`` for any synchronous read; it does the bracketing.
/// `resolveURL()` is for path-level use only (display, comparison) and does **not**
/// start access. Outbound drag uses file promises (see ``NookShelfView``) so the read
/// can hold scope for the duration of the copy.
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
    /// How the bookmark was captured. Drives ``ShelfStore``'s purge rule under the
    /// sandbox: a `.nonScoped` (or legacy `.unknown`) bookmark that fails to resolve
    /// is preserved across launches because it may resolve again later.
    public let bookmarkKind: BookmarkKind

    /// How a bookmark was captured.
    ///
    /// - `scoped`: a `.withSecurityScope` bookmark — durable across launches under the
    ///   App Sandbox.
    /// - `nonScoped`: a plain bookmark. Resolves fine outside the sandbox; **cannot**
    ///   resolve in a future sandboxed launch.
    /// - `unknown`: persisted by a build that predates this tag. Treated like
    ///   `.nonScoped` for purge — preserved when it fails to resolve.
    public enum BookmarkKind: String, Codable, Sendable, CaseIterable {
        case scoped
        case nonScoped
        case unknown
    }

    /// Builds an item from a file URL, capturing a bookmark. Returns `nil` if the URL
    /// can't be bookmarked (e.g. it doesn't exist).
    public static func make(from url: URL) -> ShelfItem? {
        guard let capture = Self.bookmarkData(for: url) else { return nil }
        let type = UTType(filenameExtension: url.pathExtension)?.identifier
            ?? UTType.data.identifier
        return ShelfItem(
            id: UUID(),
            displayName: url.deletingPathExtension().lastPathComponent,
            fileExtension: url.pathExtension,
            addedAt: Date(),
            bookmark: capture.data,
            typeIdentifier: type,
            bookmarkKind: capture.kind
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

    /// Returns a copy whose bookmark has been re-captured from `url`, or `nil` if a fresh
    /// bookmark can't be made. The caller supplies the already-resolved URL so a heal
    /// pass doesn't resolve the bookmark a second time — see ``ShelfStore``.
    ///
    /// Re-capture is also a natural moment to **upgrade** a `.nonScoped`/`.unknown` item
    /// to `.scoped` when scoped capture now succeeds (e.g. the host left the sandbox
    /// for a session). The new ``bookmarkKind`` reflects how the *fresh* bookmark was
    /// captured, not the predecessor's tag.
    func reBookmarked(from url: URL) -> ShelfItem? {
        guard let capture = Self.bookmarkData(for: url) else { return nil }
        return ShelfItem(
            id: id,
            displayName: displayName,
            fileExtension: fileExtension,
            addedAt: addedAt,
            bookmark: capture.data,
            typeIdentifier: typeIdentifier,
            bookmarkKind: capture.kind
        )
    }

    /// Captures bookmark data for `url`, reporting how it was captured.
    ///
    /// Prefers a security-scoped bookmark and falls back to a plain one (scoped
    /// creation throws when the process holds no scoped access to the file, e.g. some
    /// non-sandboxed contexts, or on volumes that don't support scoped bookmarks).
    /// Returns `nil` only when *both* attempts fail.
    static func bookmarkData(for url: URL) -> (data: Data, kind: BookmarkKind)? {
        if let scoped = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return (scoped, .scoped)
        }
        if let plain = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return (plain, .nonScoped)
        }
        return nil
    }

    // MARK: - Codable (forward-compatible decoding)

    private enum CodingKeys: String, CodingKey {
        case id, displayName, fileExtension, addedAt, bookmark, typeIdentifier, bookmarkKind
    }

    /// Custom decoder so JSON written by an older build (no `bookmarkKind` field)
    /// decodes cleanly to `.unknown` — which the purge rule treats as a non-scoped
    /// bookmark, preserving it across launches. Same pattern as
    /// ``NookAppearancePreferences``.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.fileExtension = try container.decode(String.self, forKey: .fileExtension)
        self.addedAt = try container.decode(Date.self, forKey: .addedAt)
        self.bookmark = try container.decode(Data.self, forKey: .bookmark)
        self.typeIdentifier = try container.decode(String.self, forKey: .typeIdentifier)
        self.bookmarkKind = try container.decodeIfPresent(BookmarkKind.self, forKey: .bookmarkKind) ?? .unknown
    }

    /// Explicit memberwise init: needed because the custom `init(from:)` above
    /// suppresses Swift's synthesized memberwise init.
    init(
        id: UUID,
        displayName: String,
        fileExtension: String,
        addedAt: Date,
        bookmark: Data,
        typeIdentifier: String,
        bookmarkKind: BookmarkKind
    ) {
        self.id = id
        self.displayName = displayName
        self.fileExtension = fileExtension
        self.addedAt = addedAt
        self.bookmark = bookmark
        self.typeIdentifier = typeIdentifier
        self.bookmarkKind = bookmarkKind
    }
}

/// Bookmark-resolution option sets, tried in order by ``ShelfItem/resolved()``.
private enum BookmarkResolutionOptions {
    static let securityScoped: URL.BookmarkResolutionOptions = [.withSecurityScope]
    static let plain: URL.BookmarkResolutionOptions = []
}
