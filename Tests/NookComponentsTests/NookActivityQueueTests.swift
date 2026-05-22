// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Combine
import XCTest
@testable import NookComponents
import NookKit

/// A `NookSurfacePresenting` stand-in — no real window, fully controllable engagement.
@MainActor
private final class FakePresenter: NookSurfacePresenting {
    private let engagement = CurrentValueSubject<Bool, Never>(false)

    private(set) var beginCount = 0
    private(set) var endCount = 0
    private var nextToken = 0

    /// When > 0, the next N `beginTransientPresentation(_:)` calls reject the takeover —
    /// simulating the user grabbing the surface in the pre-takeover race window.
    var rejectNextBegins = 0

    var isUserEngaged: Bool { engagement.value }

    var userEngagementChanges: AnyPublisher<Bool, Never> {
        engagement.eraseToAnyPublisher()
    }

    var activeModuleID = "test.module"

    func beginTransientPresentation(_ claim: NookSurfaceClaim) async -> NookSurfaceToken? {
        beginCount += 1
        if rejectNextBegins > 0 {
            rejectNextBegins -= 1
            return nil
        }
        guard !isUserEngaged else { return nil }
        defer { nextToken += 1 }
        return NookSurfaceToken(value: nextToken)
    }

    func endTransientPresentation(_ token: NookSurfaceToken) async { endCount += 1 }

    func setEngaged(_ value: Bool) { engagement.send(value) }
}

final class NookActivityQueueTests: XCTestCase {
    /// A queue whose `dwell` waits resolve instantly, for deterministic draining.
    @MainActor
    private func instantQueue() -> NookActivityQueue {
        NookActivityQueue(sleep: { _ in })
    }

    @MainActor
    func testDrainsEveryEnqueuedActivity() async {
        let queue = instantQueue()
        let presenter = FakePresenter()
        queue.bind(to: presenter)

        queue.enqueue(NookActivity(title: "A"))
        queue.enqueue(NookActivity(title: "B"))
        queue.enqueue(NookActivity(title: "C"))
        await queue.drainTask?.value

        XCTAssertEqual(presenter.beginCount, 3)
        XCTAssertEqual(presenter.endCount, 3)
        XCTAssertNil(queue.current)
        XCTAssertTrue(queue.pending.isEmpty)
    }

    @MainActor
    func testPresentsHighestPriorityFirst() async {
        let queue = instantQueue()
        let presenter = FakePresenter()
        queue.bind(to: presenter)

        var presented: [String] = []
        let cancellable = queue.$current
            .compactMap { $0?.title }
            .sink { presented.append($0) }

        queue.enqueue(NookActivity(priority: .low, title: "Low"))
        queue.enqueue(NookActivity(priority: .high, title: "High"))
        queue.enqueue(NookActivity(priority: .normal, title: "Normal"))
        await queue.drainTask?.value
        cancellable.cancel()

        XCTAssertEqual(presented, ["High", "Normal", "Low"])
    }

    @MainActor
    func testCoalescingKeyKeepsLatest() {
        // No presenter bound — the queue holds activities without draining.
        let queue = instantQueue()

        queue.enqueue(NookActivity(coalescingKey: "sync", title: "First"))
        queue.enqueue(NookActivity(coalescingKey: "sync", title: "Second"))

        XCTAssertEqual(queue.pending.count, 1)
        XCTAssertEqual(queue.pending.first?.title, "Second")
    }

    @MainActor
    func testSuspendStopsDrainingAndResumeContinues() async {
        let queue = instantQueue()
        let presenter = FakePresenter()

        queue.suspend()
        queue.bind(to: presenter)
        queue.enqueue(NookActivity(title: "A"))
        XCTAssertEqual(presenter.beginCount, 0, "a suspended queue presents nothing")

        queue.resume()
        await queue.drainTask?.value
        XCTAssertEqual(presenter.beginCount, 1)
    }

    /// Regression: suspending the queue *while the user is engaged* must still let the
    /// drain task observe its own cancellation. The engagement wait used to park on a
    /// duplicate-collapsing publisher that never re-emitted, leaking the cancelled task;
    /// after `resume()` the queue must drive cleanly to completion.
    @MainActor
    func testSuspendWhileEngagedThenResumeRecovers() async throws {
        let queue = instantQueue()
        let presenter = FakePresenter()
        presenter.setEngaged(true)
        queue.bind(to: presenter)

        queue.enqueue(NookActivity(title: "A"))
        // Let the drain loop reach its engaged-yield point.
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(presenter.beginCount, 0, "must not present while the user is engaged")

        // Suspend mid-yield: the drain task is cancelled and must actually unwind.
        queue.suspend()
        XCTAssertNil(queue.drainTask, "suspend clears the drain task")

        // Resume while still engaged, then disengage — the queue must not be wedged.
        queue.resume()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(presenter.beginCount, 0, "still yields after resume while engaged")

        presenter.setEngaged(false)
        await queue.drainTask?.value
        XCTAssertEqual(presenter.beginCount, 1, "queue recovers and drains after suspend-while-engaged")
        XCTAssertTrue(queue.pending.isEmpty)
        XCTAssertNil(queue.current)
    }

    /// Regression: if the user grabs the surface in the window between the engagement
    /// wait and the takeover, `beginTransientPresentation()` returns `false`. The queue
    /// must re-queue the activity and retry, not drop it or render a card over a
    /// surface it never took.
    @MainActor
    func testRequeuesActivityWhenTakeoverRejected() async {
        let queue = instantQueue()
        let presenter = FakePresenter()
        presenter.rejectNextBegins = 1
        queue.bind(to: presenter)

        queue.enqueue(NookActivity(title: "A"))
        await queue.drainTask?.value

        XCTAssertEqual(presenter.beginCount, 2, "first takeover rejected, retried once")
        XCTAssertEqual(presenter.endCount, 1, "presented exactly once, after the retry")
        XCTAssertTrue(queue.pending.isEmpty)
        XCTAssertNil(queue.current)
    }

    @MainActor
    func testYieldsWhileUserEngaged() async throws {
        let queue = instantQueue()
        let presenter = FakePresenter()
        presenter.setEngaged(true)
        queue.bind(to: presenter)

        queue.enqueue(NookActivity(title: "A"))
        // Give the drain loop time to reach its yield point.
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(presenter.beginCount, 0, "must not present while the user is engaged")

        presenter.setEngaged(false)
        await queue.drainTask?.value
        XCTAssertEqual(presenter.beginCount, 1, "presents once the user disengages")
    }
}
