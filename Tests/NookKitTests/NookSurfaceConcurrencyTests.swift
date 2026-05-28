// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the MIT License.
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI
import XCTest

@testable import NookSurface

/// Coverage for the NookSurface concurrency fixes: the explicit drag-session state
/// machine (robust against AppKit's uncoordinated callbacks) and the hide-vs-expand
/// transition supersession (hide now runs fully inside the generation system).
///
/// These exercise `Nook`'s internal model without depending on a real display: the
/// drag-session and generation logic is pure state, and `nookPanelDraggingEntered`
/// only spawns a transition when a screen resolves — with no screen attached the
/// session bookkeeping still runs and is what we assert on.
@MainActor
final class NookSurfaceConcurrencyTests: XCTestCase {

    private func makeNook() -> Nook<Text, EmptyView, EmptyView> {
        Nook(expanded: { Text("x") })
    }

    // MARK: - BUG 2: drag-session state machine

    /// A fresh enter snapshots the current state; the session reports active.
    func testFirstDragEnterSnapshotsStateAndGoesActive() {
        let nook = makeNook()
        XCTAssertEqual(nook.dragSession, .idle)
        XCTAssertFalse(nook.isDragInFlight)

        _ = nook.nookPanelDraggingEntered([URL(fileURLWithPath: "/tmp/a")])

        XCTAssertEqual(nook.dragSession, .active(stateBeforeEntry: .hidden))
        XCTAssertTrue(nook.isDragInFlight)
    }

    /// Every `draggingUpdated` forwards as another enter. Repeated enters must keep the
    /// *original* snapshot — they are idempotent no-ops on session state.
    func testRepeatedDragEntersPreserveOriginalSnapshot() {
        let nook = makeNook()
        let url = URL(fileURLWithPath: "/tmp/a")

        _ = nook.nookPanelDraggingEntered([url])
        let afterFirst = nook.dragSession
        _ = nook.nookPanelDraggingEntered([url])
        _ = nook.nookPanelDraggingEntered([url])

        XCTAssertEqual(nook.dragSession, afterFirst)
        XCTAssertEqual(nook.dragSession, .active(stateBeforeEntry: .hidden))
    }

    /// AppKit can deliver `draggingExited` *then* `draggingEnded` for one session — both
    /// route through `nookPanelDraggingExited`. The second call must be an idempotent
    /// no-op: the snapshot was consumed by the first, so the session stays idle and the
    /// prior state is not restored twice.
    func testDuplicateExitIsIdempotent() {
        let nook = makeNook()
        _ = nook.nookPanelDraggingEntered([URL(fileURLWithPath: "/tmp/a")])
        XCTAssertTrue(nook.isDragInFlight)

        nook.nookPanelDraggingExited()
        XCTAssertEqual(nook.dragSession, .idle)
        XCTAssertFalse(nook.isDragInFlight)

        // Out-of-order / duplicate end callback — must not corrupt state.
        nook.nookPanelDraggingExited()
        XCTAssertEqual(nook.dragSession, .idle)
        XCTAssertFalse(nook.isDragInFlight)
    }

    /// An exit with no preceding enter (stray callback) must be a harmless no-op.
    func testExitWithoutEnterIsNoOp() {
        let nook = makeNook()
        nook.nookPanelDraggingExited()
        XCTAssertEqual(nook.dragSession, .idle)
        XCTAssertFalse(nook.isDragInFlight)
    }

    /// A drop ends the session exactly once; a trailing exit/end AppKit delivers around
    /// the drop cannot re-trigger a restore.
    func testDropEndsSessionAndTrailingExitIsNoOp() {
        let nook = makeNook()
        var dropped: [URL] = []
        nook.onFileDrop = { urls in dropped = urls; return true }

        _ = nook.nookPanelDraggingEntered([URL(fileURLWithPath: "/tmp/a")])
        let accepted = nook.nookPanelPerformDrop([URL(fileURLWithPath: "/tmp/a")])

        XCTAssertTrue(accepted)
        XCTAssertEqual(dropped.count, 1)
        XCTAssertEqual(nook.dragSession, .idle)
        XCTAssertFalse(nook.isDragInFlight)

        // AppKit's post-drop exit/end — idempotent no-op.
        nook.nookPanelDraggingExited()
        XCTAssertEqual(nook.dragSession, .idle)
    }

    /// A drop with no preceding enter still ends cleanly and does not wedge the session.
    func testDropWithoutEnterIsHandledCleanly() {
        let nook = makeNook()
        nook.onFileDrop = { _ in false }
        let accepted = nook.nookPanelPerformDrop([URL(fileURLWithPath: "/tmp/a")])
        XCTAssertFalse(accepted)
        XCTAssertEqual(nook.dragSession, .idle)
        XCTAssertFalse(nook.isDragInFlight)
    }

    /// `isDragInFlight` is a strict mirror of `dragSession` — observers of the published
    /// bool see exactly the active/idle of the authoritative enum.
    func testIsDragInFlightMirrorsSession() {
        let nook = makeNook()
        XCTAssertFalse(nook.isDragInFlight)

        nook.dragSession = .active(stateBeforeEntry: .compact)
        XCTAssertTrue(nook.isDragInFlight)

        nook.dragSession = .idle
        XCTAssertFalse(nook.isDragInFlight)
    }

    // MARK: - BUG 1: hide-vs-expand supersession

    /// `runTransition` claims a fresh generation synchronously and invalidates the prior
    /// one. A generation a transition's body captured is no longer `isCurrent` once a
    /// newer transition has been claimed — this is the signal an in-flight `_hide`
    /// re-checks to bail out of its teardown rather than deinit a window the newer
    /// transition owns.
    func testNewerTransitionSupersedesAnEarlierGeneration() async {
        let nook = makeNook()

        // A hide-like transition captures its generation, then yields so a newer
        // transition can be claimed while it is "in flight".
        var hideStillCurrentAfterSupersede: Bool?
        let hideTask = nook.runTransition { generation in
            // Cooperatively yield: lets the second `runTransition` below claim a
            // newer generation, mimicking an expand racing this hide's teardown.
            await Task.yield()
            hideStillCurrentAfterSupersede = nook.isCurrent(generation)
        }

        var expandGenerationIsCurrent: Bool?
        let expandTask = nook.runTransition { generation in
            expandGenerationIsCurrent = nook.isCurrent(generation)
        }

        await hideTask.value
        await expandTask.value

        // The hide observed itself superseded after the yield — its teardown bails.
        XCTAssertEqual(hideStillCurrentAfterSupersede, false)
        // The expand is the most recent claim and owns the surface.
        XCTAssertEqual(expandGenerationIsCurrent, true)
    }

    /// `supersedeInFlightTransition` — used by the synchronous window-swap paths
    /// (`presentation.didSet`, screen-parameter observer) — invalidates any in-flight
    /// generation so a mid-flight `_expand`/`_compact`/`_hide` bails when the window is
    /// rebuilt under it.
    func testWindowSwapSupersedesInFlightTransition() async {
        let nook = makeNook()
        var stillCurrentAfterSwap: Bool?

        let task = nook.runTransition { generation in
            await Task.yield()
            stillCurrentAfterSwap = nook.isCurrent(generation)
        }
        // Swap the window out from under the in-flight transition.
        nook.supersedeInFlightTransition()
        await task.value

        XCTAssertEqual(stillCurrentAfterSwap, false)
    }

    /// An awaited `hide()` always resolves — it now routes through `runTransition` like
    /// `expand`/`compact`, so the awaited task completes rather than wedging on a dropped
    /// continuation. With no window to tear down it is effectively a fast no-op.
    func testAwaitedHideOnHiddenNookResolves() async {
        let nook = makeNook()
        XCTAssertEqual(nook.state, .hidden)
        // Must not hang: `_hide` returns immediately when already hidden.
        await nook.hide()
        XCTAssertEqual(nook.state, .hidden)
    }

    // MARK: - Peripheral feedback lifecycle

    private func feedbackEvent(duration: TimeInterval, repeats: Bool) -> NookFeedbackEvent {
        NookFeedbackEvent(
            id: UUID(), startedAt: Date(), effect: .shimmer, duration: duration,
            tint: .white, respectsReduceMotion: true, repeats: repeats
        )
    }

    /// A one-shot cue must auto-clear once it has finished, otherwise the overlay's
    /// `TimelineView(.animation)` keeps ticking at 60fps forever rendering `Color.clear`.
    func testOneShotFeedbackClearsAfterDuration() async {
        let nook = makeNook()
        nook.setFeedbackEvent(feedbackEvent(duration: 0.05, repeats: false))
        XCTAssertNotNil(nook.feedbackEvent)

        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNil(nook.feedbackEvent, "finished one-shot cue must clear so the timeline tears down")
    }

    /// A repeating cue is meant to nag until acknowledged, so it must persist past its
    /// per-cycle duration.
    func testRepeatingFeedbackPersists() async {
        let nook = makeNook()
        nook.setFeedbackEvent(feedbackEvent(duration: 0.05, repeats: true))

        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertNotNil(nook.feedbackEvent, "repeating cue must keep running until acknowledged")
    }

    /// A new cue cancels the prior cue's pending clear, so the first event's timer can't
    /// nil out the replacement.
    func testNewFeedbackSupersedesPriorClear() async {
        let nook = makeNook()
        nook.setFeedbackEvent(feedbackEvent(duration: 0.05, repeats: false))
        let second = feedbackEvent(duration: 1.0, repeats: false)
        nook.setFeedbackEvent(second)

        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(nook.feedbackEvent?.id, second.id, "the first cue's clear must not nil the second")
    }
}
