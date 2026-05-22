// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// Observable model backing the notch file shelf.
///
/// A host owns one `ShelfStore`, renders it with ``NookShelfView``, and wires
/// ``accept(_:)`` into `NookConfiguration.onFileDrop`. The store persists itself to
/// `UserDefaults` (as encoded ``ShelfItem`` bookmarks) and reloads on the next launch,
/// dropping any items whose files have since disappeared.
///
/// `@MainActor`-isolated: the `@Published` `items` drives SwiftUI, and every mutation
/// path arrives on the main actor — file drops are delivered by the (main-actor) `Nook`
/// surface, and SwiftUI interactions are main-actor by definition. This matches the
/// concurrency contract of `NookActivityQueue`.
@MainActor
public final class ShelfStore: ObservableObject {
    /// Shelved files, oldest first.
    @Published public private(set) var items: [ShelfItem] = []

    /// How strictly ``accept(_:)`` treats non-scoped bookmark captures.
    ///
    /// - ``lenient``: the default. Accept a non-scoped bookmark even under the App
    ///   Sandbox — the purge rule will preserve it across launches, so the user keeps
    ///   the entry even though it won't resolve in a sandboxed reload.
    /// - ``strict``: under the App Sandbox, refuse to accept an item whose scoped
    ///   capture failed. Better than silently degrading when the host wants drops to
    ///   either work durably or visibly fail.
    public enum AcceptanceMode: Sendable {
        case lenient
        case strict
    }

    /// Controls ``accept(_:)`` behavior; see ``AcceptanceMode``. Defaults to
    /// `.lenient` so existing hosts are unaffected.
    public var acceptanceMode: AcceptanceMode

    private let persistenceKey: String
    private let defaults: UserDefaults
    /// Logged once per process when a non-scoped bookmark is captured under the
    /// sandbox, so a host can grep `log show` for the diagnostic without us spamming
    /// it on every drop.
    private var hasLoggedSandboxedFallback = false

    /// - Parameters:
    ///   - persistenceKey: `UserDefaults` key the encoded shelf is stored under.
    ///   - defaults: the `UserDefaults` instance — injectable for tests.
    ///   - acceptanceMode: see ``AcceptanceMode``; defaults to `.lenient`.
    public init(
        persistenceKey: String = "nook.shelf.items",
        defaults: UserDefaults = .standard,
        acceptanceMode: AcceptanceMode = .lenient
    ) {
        self.persistenceKey = persistenceKey
        self.defaults = defaults
        self.acceptanceMode = acceptanceMode
        loadAndReconcile()
    }

    /// Adds files to the shelf, skipping any already present (compared by resolved path).
    /// Drop-in for `NookConfiguration.onFileDrop` — returns `true` if at least one file
    /// was added, which keeps the nook expanded so the shelf is visible.
    ///
    /// Under the App Sandbox in ``AcceptanceMode/strict`` mode, items whose scoped
    /// bookmark capture failed are dropped silently (returned `false` if no items
    /// remain). In `.lenient` (the default) such items are accepted with a
    /// `.nonScoped` tag — the purge rule will preserve them across launches.
    @discardableResult
    public func accept(_ urls: [URL]) -> Bool {
        // Dedup is a *path-level* comparison, so `resolveURL()` (no security scope) is
        // the right call here — and is deliberately not wrapped in `withResolvedURL`.
        // Per `ShelfItem`'s contract, security-scoped access is only needed to touch a
        // file's *contents*; resolving a bookmark to a URL for comparison does not need
        // it. Bracketing here would start/stop scoped access for no read — pure overhead.
        let existing = Set(items.compactMap { $0.resolveURL()?.standardizedFileURL.path })
        let candidates = urls
            .filter { !existing.contains($0.standardizedFileURL.path) }
            .compactMap { ShelfItem.make(from: $0) }

        let admitted: [ShelfItem]
        switch acceptanceMode {
        case .lenient:
            admitted = candidates
        case .strict:
            // Under the sandbox, a non-scoped capture is a durability bomb — refuse it.
            // Outside the sandbox, a non-scoped fallback is fine and admitted normally.
            admitted = ShelfRuntime.isSandboxed
                ? candidates.filter { $0.bookmarkKind == .scoped }
                : candidates
        }

        // One-shot diagnostic if we let a sandboxed non-scoped capture through.
        if !hasLoggedSandboxedFallback,
           ShelfRuntime.isSandboxed,
           admitted.contains(where: { $0.bookmarkKind == .nonScoped }) {
            hasLoggedSandboxedFallback = true
            ShelfRuntime.log.warning(
                "Captured non-scoped bookmark under App Sandbox; the entry will not resolve in a future launch but is preserved across the current session."
            )
        }

        guard !admitted.isEmpty else { return false }
        items.append(contentsOf: admitted)
        persist()
        return true
    }

    public func remove(_ item: ShelfItem) {
        remove(id: item.id)
    }

    public func remove(id: ShelfItem.ID) {
        let before = items.count
        items.removeAll { $0.id == id }
        if items.count != before { persist() }
    }

    public func clear() {
        guard !items.isEmpty else { return }
        items.removeAll()
        persist()
    }

    /// Drops items whose file is genuinely gone. Called via ``loadAndReconcile()`` on
    /// `init`; a host can call this again (e.g. when the shelf surface appears).
    ///
    /// A resolution failure is **ambiguous** at two levels and the rule handles both:
    ///
    /// 1. **Per-item ambiguity (non-scoped bookmark under the sandbox).** A
    ///    `.nonScoped` or `.unknown` bookmark cannot resolve in a sandboxed launch
    ///    even when the file is right there. So these items are **never purged** on
    ///    resolution failure — they remain on the shelf and may resolve in a later
    ///    non-sandboxed launch, or get upgraded by a re-add. Only `.scoped` items can
    ///    be purged.
    /// 2. **Systemic ambiguity (everything fails).** Even among `.scoped` items, if
    ///    *every* resolvable candidate fails — indistinguishable from a sandboxed host
    ///    losing its grant entirely — nothing is dropped.
    public func purgeMissing() {
        guard !items.isEmpty else { return }
        let resolutions = items.map { ($0, $0.resolveURL()) }
        let resolvable = resolutions.filter { $0.0.bookmarkKind == .scoped }
        // Systemic-failure guard: only drop scoped items when at least one scoped item
        // resolved. Otherwise the failure is plausibly a lost grant — preserve it all.
        guard resolvable.contains(where: { $0.1 != nil }) else { return }

        let before = items.count
        items = resolutions.compactMap { item, resolved in
            switch item.bookmarkKind {
            case .scoped:
                return resolved == nil ? nil : item
            case .nonScoped, .unknown:
                // Always preserve: a resolution failure is plausibly recoverable.
                return item
            }
        }
        if items.count != before { persist() }
    }

    /// Loads the persisted shelf and reconciles it in a **single pass** over every item,
    /// resolving each bookmark exactly once. For each item that pass does two things:
    ///
    /// - **Heal:** a bookmark that resolves but reports itself stale (file moved across
    ///   volumes, OS bookmark-format migration) is re-captured from the resolved URL.
    ///   Apple's contract is to re-bookmark from there; left unhealed it eventually
    ///   stops resolving. Re-capture also **upgrades** a `.nonScoped`/`.unknown` item
    ///   to `.scoped` when scoped capture now succeeds.
    /// - **Purge:** an item whose bookmark fails to resolve is a *candidate* for
    ///   removal — but only if it was `.scoped` and a sibling `.scoped` item still
    ///   resolves. `.nonScoped` and `.unknown` items are always preserved on
    ///   resolution failure (see ``purgeMissing()``).
    ///
    /// This is the consolidation of what used to be three separate full passes
    /// (`load` + `healStaleBookmarks` + `purgeMissing`) and is behaviour-preserving.
    private func loadAndReconcile() {
        guard let data = defaults.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) else {
            return
        }

        // One resolution per item, reused for both the heal and the purge decision.
        let reconciled: [(item: ShelfItem, resolved: Bool, healed: Bool)] = decoded.map { item in
            guard let resolution = item.resolved() else {
                return (item, false, false)
            }
            if resolution.isStale, let fresh = item.reBookmarked(from: resolution.url) {
                return (fresh, true, true)
            }
            return (item, true, false)
        }

        // Among scoped items, purge only when at least one scoped sibling resolved —
        // systemic failure preserves everything. Non-scoped/unknown items are always
        // preserved on failure.
        let anyScopedResolved = reconciled.contains { $0.item.bookmarkKind == .scoped && $0.resolved }
        let kept = reconciled.filter { entry in
            switch entry.item.bookmarkKind {
            case .scoped:
                return anyScopedResolved ? entry.resolved : true
            case .nonScoped, .unknown:
                return true
            }
        }

        items = kept.map(\.item)

        let droppedAny = kept.count != decoded.count
        let healedAny = kept.contains { $0.healed }
        if droppedAny || healedAny { persist() }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: persistenceKey)
    }
}
