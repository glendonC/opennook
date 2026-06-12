// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import AppKit

// File-drag state machine and `NookDragDestination` conformance for ``Nook``.
//
// AppKit delivers drag-session callbacks (`draggingEntered`/`Updated`/`Exited`/
// `Ended`, `performDragOperation`) on the main thread but with no ordering
// guarantee a state machine can lean on: `draggingExited` can arrive *before*
// `draggingEnded` for one session, a slow or rejected `onFileDrop` can let a fresh
// `draggingEntered` interleave, and `draggingUpdated` fires repeatedly. The
// ``Nook/DragSession`` enum below collapses all that into a single owner whose
// transitions are idempotent.
//
// Lives in its own file so `Nook.swift` stays focused on lifecycle/transition
// concerns. The stored `dragSession` property is still declared on `Nook` itself - 
// only the surrounding state machine and the destination-callback conformance
// extract here.

extension Nook {
    /// Single explicit owner of a file-drag session's mutable state.
    ///
    /// AppKit delivers drag-session callbacks (`draggingEntered`/`Updated`/`Exited`/
    /// `Ended`, `performDragOperation`) on the main thread but with no ordering
    /// guarantee a state machine can lean on: `draggingExited` can arrive *before*
    /// `draggingEnded` for one session, a slow or rejected `onFileDrop` can let a fresh
    /// `draggingEntered` interleave, and `draggingUpdated` fires repeatedly. Rather than
    /// scatter `stateBeforeDrag`/`isDragInFlight` mutations across those entry points - 
    /// correct only by luck of ordering - the whole session lives in this one enum with
    /// idempotent transitions.
    enum DragSession: Equatable {
        /// No drag over the panel.
        case idle
        /// A drag is over the panel. `stateBeforeEntry` is the `NookState` captured at
        /// the *first* enter of this session, so a later exit/rejected-drop can restore it.
        case active(stateBeforeEntry: NookState)
    }
}

// MARK: - NookDragDestination

extension Nook: NookDragDestination {
    /// Called when AppKit reports a file drag is over the panel. The *first* enter of a
    /// session snapshots the prior state and auto-expands a collapsed panel so the drop
    /// zone is visible; subsequent enters (every `draggingUpdated` forwards here) are
    /// idempotent no-ops that preserve the original snapshot.
    func nookPanelDraggingEntered(_ urls: [URL]) -> NSDragOperation {
        guard case .idle = dragSession else {
            // Already active - a forwarded `draggingUpdated`, or a duplicate enter.
            // Keep the original snapshot; the advertised operation is unchanged.
            return .copy
        }

        // First enter of this session: snapshot now, before the auto-expand mutates state.
        let stateBeforeEntry = state
        dragSession = .active(stateBeforeEntry: stateBeforeEntry)

        if stateBeforeEntry == .compact || stateBeforeEntry == .hidden {
            if let screen = windowController?.window?.screen ?? resolvedScreen {
                runTransition { [weak self] generation in
                    await self?._expand(on: screen, skipHide: true, generation: generation)
                }
            }
        }
        return .copy
    }

    /// Drag left without dropping. Restores the pre-drag state. Idempotent: a duplicate
    /// or out-of-order `draggingExited`/`draggingEnded` after the session already ended
    /// is a no-op, because the snapshot was consumed by the first end.
    func nookPanelDraggingExited() {
        endDragSession(restorePriorState: true)
    }

    /// File drop landed. Hand the URLs to the registered callback; if it accepts, leave
    /// the nook expanded so the registration UI is visible, otherwise restore prior
    /// state. The session is ended *before* restoring, so a `draggingExited`/`Ended`
    /// that AppKit delivers around the drop can't double-restore.
    func nookPanelPerformDrop(_ urls: [URL]) -> Bool {
        let accepted = onFileDrop?(urls) ?? false
        endDragSession(restorePriorState: !accepted)
        return accepted
    }

    /// End the current drag session exactly once. Reads the snapshot out of the session
    /// state, flips it to `.idle`, and - if asked - restores the captured prior state.
    /// Calling this when already `.idle` is a no-op, which is what makes the destination
    /// robust against AppKit's duplicate and out-of-order exit/end/drop callbacks.
    private func endDragSession(restorePriorState: Bool) {
        guard case let .active(stateBeforeEntry) = dragSession else { return }
        dragSession = .idle
        if restorePriorState {
            restoreStateAfterDrag(stateBeforeEntry)
        }
    }

    /// Restore the surface to its pre-drag state after an aborted drag or a rejected
    /// drop. Shared by ``nookPanelDraggingExited()`` and ``nookPanelPerformDrop(_:)``.
    private func restoreStateAfterDrag(_ prior: NookState) {
        switch prior {
        case .compact:
            guard let screen = windowController?.window?.screen ?? resolvedScreen else { return }
            runTransition { [weak self] generation in
                await self?._compact(on: screen, skipHide: true, generation: generation)
            }
        case .hidden:
            runTransition { [weak self] generation in
                await self?._hide(generation: generation)
            }
        case .expanded:
            break
        }
    }
}
