// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import XCTest
@testable import NookComponents

@MainActor
final class ShelfStoreTests: XCTestCase {
    /// Writes a throwaway file into the temp directory and returns its URL.
    private func makeTempFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nook-shelf-\(UUID().uuidString)")
            .appendingPathExtension("txt")
        try Data("nook".utf8).write(to: url)
        return url
    }

    /// A store backed by a unique, isolated `UserDefaults` suite so tests don't collide.
    private func freshStore() -> (store: ShelfStore, defaults: UserDefaults, key: String) {
        let defaults = UserDefaults(suiteName: "nook.test.\(UUID().uuidString)")!
        let key = "items"
        return (ShelfStore(persistenceKey: key, defaults: defaults), defaults, key)
    }

    func testAcceptAddsResolvableItem() throws {
        let (store, _, _) = freshStore()
        let url = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(store.accept([url]))
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(
            store.items.first?.resolveURL()?.standardizedFileURL,
            url.standardizedFileURL
        )
    }

    func testAcceptSkipsDuplicates() throws {
        let (store, _, _) = freshStore()
        let url = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(store.accept([url]))
        XCTAssertFalse(store.accept([url]), "the same file should not be shelved twice")
        XCTAssertEqual(store.items.count, 1)
    }

    func testRemoveAndClear() throws {
        let (store, _, _) = freshStore()
        let first = try makeTempFile()
        let second = try makeTempFile()
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        store.accept([first, second])
        XCTAssertEqual(store.items.count, 2)

        store.remove(store.items[0])
        XCTAssertEqual(store.items.count, 1)

        store.clear()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testPersistenceRoundTrip() throws {
        let url = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let defaults = UserDefaults(suiteName: "nook.test.\(UUID().uuidString)")!
        let key = "items"

        let first = ShelfStore(persistenceKey: key, defaults: defaults)
        first.accept([url])

        // A second store over the same defaults must reload the shelved file.
        let second = ShelfStore(persistenceKey: key, defaults: defaults)
        XCTAssertEqual(second.items.count, 1)
        XCTAssertEqual(second.items.first?.resolveURL()?.standardizedFileURL, url.standardizedFileURL)
    }

    func testPurgeMissingDropsIndividualDeletedFile() throws {
        let (store, _, _) = freshStore()
        let kept = try makeTempFile()
        let deleted = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: kept) }

        store.accept([kept, deleted])
        XCTAssertEqual(store.items.count, 2)

        // With a surviving sibling, access is clearly working — so the one genuinely
        // missing file should be purged.
        try FileManager.default.removeItem(at: deleted)
        store.purgeMissing()
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.resolveURL()?.standardizedFileURL, kept.standardizedFileURL)
    }

    /// Regression: when *every* item fails to resolve — indistinguishable from a
    /// sandboxed host that lost its file-access grant — the shelf must be preserved,
    /// not silently wiped.
    func testPurgeMissingPreservesShelfOnSystemicFailure() throws {
        let (store, _, _) = freshStore()
        let first = try makeTempFile()
        let second = try makeTempFile()

        store.accept([first, second])
        XCTAssertEqual(store.items.count, 2)

        try FileManager.default.removeItem(at: first)
        try FileManager.default.removeItem(at: second)
        store.purgeMissing()
        XCTAssertEqual(store.items.count, 2, "a total resolution failure must not wipe the shelf")
    }

    /// The consolidated `init` reconcile (load + heal + purge in one pass) must purge an
    /// individually-deleted file on launch, exactly as `purgeMissing()` does — proving
    /// the single-pass consolidation preserves the per-item purge behaviour.
    func testInitReconcilePurgesIndividualDeletedFile() throws {
        let defaults = UserDefaults(suiteName: "nook.test.\(UUID().uuidString)")!
        let key = "items"
        let kept = try makeTempFile()
        let deleted = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: kept) }

        let first = ShelfStore(persistenceKey: key, defaults: defaults)
        first.accept([kept, deleted])
        XCTAssertEqual(first.items.count, 2)

        // Delete one file, then construct a fresh store: its init reconcile sees a
        // surviving sibling, so the genuinely-missing file is dropped on load.
        try FileManager.default.removeItem(at: deleted)
        let reloaded = ShelfStore(persistenceKey: key, defaults: defaults)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.resolveURL()?.standardizedFileURL, kept.standardizedFileURL)
    }

    /// The consolidated `init` reconcile must also honour the systemic-failure rule:
    /// when *every* persisted item fails to resolve on launch, the shelf is preserved.
    func testInitReconcilePreservesShelfOnSystemicFailure() throws {
        let defaults = UserDefaults(suiteName: "nook.test.\(UUID().uuidString)")!
        let key = "items"
        let first = try makeTempFile()
        let second = try makeTempFile()

        let store = ShelfStore(persistenceKey: key, defaults: defaults)
        store.accept([first, second])
        XCTAssertEqual(store.items.count, 2)

        try FileManager.default.removeItem(at: first)
        try FileManager.default.removeItem(at: second)
        let reloaded = ShelfStore(persistenceKey: key, defaults: defaults)
        XCTAssertEqual(reloaded.items.count, 2, "a total resolution failure on init must not wipe the shelf")
    }

    // MARK: - Bookmark-kind tag

    /// Outside the App Sandbox (where every test runs) scoped capture should still
    /// succeed for any URL the process can read. The tag records that.
    func testBookmarkKindIsScopedWhenAvailable() throws {
        let (store, _, _) = freshStore()
        let url = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(store.accept([url]))
        XCTAssertEqual(store.items.first?.bookmarkKind, .scoped)
    }

    /// REGRESSION: a `.nonScoped` item that fails to resolve must NOT be purged on
    /// reconcile, even when a sibling resolves. Before the fix, a sandboxed host's
    /// non-scoped items were silently corroded on every launch.
    func testNonScopedItemPreservedOnReconcileWhenUnresolvable() throws {
        let defaults = UserDefaults(suiteName: "nook.test.\(UUID().uuidString)")!
        let key = "items"
        let alive = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: alive) }

        // Synthesise two items by hand so we can control the bookmarkKind tag and
        // produce a deliberately broken (unresolvable) bookmark for the non-scoped one.
        let aliveItem = ShelfItem.make(from: alive)!
        let nonScoped = ShelfItem(
            id: UUID(),
            displayName: "ghost",
            fileExtension: "txt",
            addedAt: Date(),
            bookmark: Data(repeating: 0xff, count: 32),  // garbage — will not resolve
            typeIdentifier: "public.plain-text",
            bookmarkKind: .nonScoped
        )
        let encoded = try JSONEncoder().encode([aliveItem, nonScoped])
        defaults.set(encoded, forKey: key)

        let store = ShelfStore(persistenceKey: key, defaults: defaults)
        XCTAssertEqual(
            store.items.count, 2,
            "the non-scoped item survives even though it cannot resolve — this is the corrosion regression test"
        )
        XCTAssertTrue(store.items.contains(where: { $0.bookmarkKind == .nonScoped }))
    }

    /// A `.scoped` item that fails to resolve, alongside a `.scoped` sibling that
    /// does resolve, IS purged. The lenient rule applies only to non-scoped items.
    func testScopedItemPurgedOnReconcileWhenUnresolvableWithLiveSibling() throws {
        let defaults = UserDefaults(suiteName: "nook.test.\(UUID().uuidString)")!
        let key = "items"
        let alive = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: alive) }

        let aliveItem = ShelfItem.make(from: alive)!
        let scopedGhost = ShelfItem(
            id: UUID(),
            displayName: "ghost",
            fileExtension: "txt",
            addedAt: Date(),
            bookmark: Data(repeating: 0xff, count: 32),
            typeIdentifier: "public.plain-text",
            bookmarkKind: .scoped
        )
        let encoded = try JSONEncoder().encode([aliveItem, scopedGhost])
        defaults.set(encoded, forKey: key)

        let store = ShelfStore(persistenceKey: key, defaults: defaults)
        XCTAssertEqual(store.items.count, 1, "a scoped sibling resolves, so the dead scoped item is purged")
        XCTAssertEqual(store.items.first?.id, aliveItem.id)
    }

    /// Items persisted before the `bookmarkKind` field existed decode as `.unknown`
    /// and are treated exactly like `.nonScoped` for purge — preserved on failure.
    func testUnknownKindTreatedAsNonScopedForPurge() throws {
        let defaults = UserDefaults(suiteName: "nook.test.\(UUID().uuidString)")!
        let key = "items"
        let alive = try makeTempFile()
        defer { try? FileManager.default.removeItem(at: alive) }

        // Emit JSON missing the `bookmarkKind` key — the shape an older build wrote.
        let aliveItem = ShelfItem.make(from: alive)!
        let aliveDict: [String: Any] = [
            "id": aliveItem.id.uuidString,
            "displayName": aliveItem.displayName,
            "fileExtension": aliveItem.fileExtension,
            "addedAt": ISO8601DateFormatter().string(from: aliveItem.addedAt),
            "bookmark": aliveItem.bookmark.base64EncodedString(),
            "typeIdentifier": aliveItem.typeIdentifier
        ]
        let ghostDict: [String: Any] = [
            "id": UUID().uuidString,
            "displayName": "ghost",
            "fileExtension": "txt",
            "addedAt": ISO8601DateFormatter().string(from: Date()),
            "bookmark": Data(repeating: 0xff, count: 32).base64EncodedString(),
            "typeIdentifier": "public.plain-text"
        ]
        // We avoid JSONSerialization here because JSONEncoder writes Dates and Data
        // with specific encodings — emit those by hand to match its defaults exactly.
        let json = """
        [
          {"id":"\(aliveItem.id.uuidString)",
           "displayName":"\(aliveItem.displayName)",
           "fileExtension":"\(aliveItem.fileExtension)",
           "addedAt":\(aliveItem.addedAt.timeIntervalSinceReferenceDate),
           "bookmark":"\(aliveItem.bookmark.base64EncodedString())",
           "typeIdentifier":"\(aliveItem.typeIdentifier)"},
          {"id":"\(ghostDict["id"]!)",
           "displayName":"ghost",
           "fileExtension":"txt",
           "addedAt":\(Date().timeIntervalSinceReferenceDate),
           "bookmark":"\(Data(repeating: 0xff, count: 32).base64EncodedString())",
           "typeIdentifier":"public.plain-text"}
        ]
        """
        _ = aliveDict; _ = ghostDict  // dict forms shown above for documentation
        let data = json.data(using: .utf8)!
        defaults.set(data, forKey: key)

        let store = ShelfStore(persistenceKey: key, defaults: defaults)
        XCTAssertEqual(store.items.count, 2, "an unknown-tagged ghost survives reconcile")
        XCTAssertTrue(
            store.items.allSatisfy { $0.bookmarkKind == .unknown || $0.bookmarkKind == .scoped },
            "items decode with .unknown when the field is missing in the persisted JSON"
        )
    }
}
