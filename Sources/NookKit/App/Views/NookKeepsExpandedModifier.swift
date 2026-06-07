// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import SwiftUI

/// Brief grace after a popover/menu/sheet binding goes `false` before the
/// presentation pin releases. Covers menu selection side-effects and the
/// layout resize that often follows popover dismissal.
enum NookKeepsExpandedGrace {
    static let postPresentationDuration: Duration = .milliseconds(400)
}

public extension View {
    /// Hold the notch surface expanded while `condition.wrappedValue` is `true`.
    ///
    /// Pair with the same binding you pass to `.popover(isPresented:)`,
    /// `.sheet(isPresented:)`, or `.alert(_:isPresented:)`. While the binding is
    /// `true`, the surface stays open and counts as user-engaged (denying
    /// competing arbiter claims); on `false` the pin releases after a brief grace
    /// so menu selection and the ensuing layout resize do not immediately expose
    /// hover-exit auto-compact. View teardown releases immediately. See
    /// ``NookPresentationPinning``.
    ///
    /// ```swift
    /// Button("Pick time") { showingPicker = true }
    ///     .popover(isPresented: $showingPicker) { TimePicker() }
    ///     .nookKeepsExpanded(while: $showingPicker)
    /// ```
    func nookKeepsExpanded(while condition: Binding<Bool>) -> some View {
        modifier(NookKeepsExpandedBoolModifier(condition: condition))
    }

    /// Hold the notch surface expanded while `item.wrappedValue != nil`.
    ///
    /// The item-binding variant for `.popover(item:)` / `.sheet(item:)` /
    /// `.alert(item:)`. Pin acquired on `nil` -> non-nil, released on
    /// non-nil -> `nil` or view teardown.
    ///
    /// ```swift
    /// .popover(item: $selectedTime) { TimeEditor(time: $0) }
    /// .nookKeepsExpanded(while: $selectedTime)
    /// ```
    func nookKeepsExpanded<Item>(while item: Binding<Item?>) -> some View {
        modifier(NookKeepsExpandedItemModifier(item: item))
    }
}

/// Implementation for the `Binding<Bool>` overload.
///
/// `@State` owns the live ``NookPresentationPinHandle``. The handle's lifetime
/// is structurally bounded by the view: when the view disappears SwiftUI tears
/// down the `@State`, which drops the handle; the handle's deinit fallback
/// releases the pin even if `onDisappear` somehow does not run. The explicit
/// `release()` path runs on `onChange` / `onDisappear` so common cases release
/// promptly instead of waiting for the next ARC cycle.
private struct NookKeepsExpandedBoolModifier: ViewModifier {
    @Binding var condition: Bool
    @Environment(\.appServices) private var services
    @State private var handle: NookPresentationPinHandle?
    @State private var releaseTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear { sync(to: condition) }
            .onChange(of: condition) { _, newValue in sync(to: newValue) }
            .onDisappear { releaseImmediately() }
    }

    private func sync(to active: Bool) {
        if active {
            releaseTask?.cancel()
            releaseTask = nil
            if handle == nil {
                handle = services.resolve(NookPresentationPinningKey.self).pin(reason: "view-modifier")
            }
        } else {
            scheduleRelease()
        }
    }

    private func scheduleRelease() {
        guard handle != nil else { return }
        releaseTask?.cancel()
        releaseTask = Task {
            try? await Task.sleep(for: NookKeepsExpandedGrace.postPresentationDuration)
            guard !Task.isCancelled else { return }
            releaseImmediately()
        }
    }

    private func releaseImmediately() {
        releaseTask?.cancel()
        releaseTask = nil
        handle?.release()
        handle = nil
    }
}

/// Implementation for the `Binding<Item?>` overload. Mirrors the Bool variant
/// with `item != nil` as the condition.
private struct NookKeepsExpandedItemModifier<Item>: ViewModifier {
    @Binding var item: Item?
    @Environment(\.appServices) private var services
    @State private var handle: NookPresentationPinHandle?
    @State private var releaseTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear { sync(to: item != nil) }
            .onChange(of: item == nil) { _, isNil in sync(to: !isNil) }
            .onDisappear { releaseImmediately() }
    }

    private func sync(to active: Bool) {
        if active {
            releaseTask?.cancel()
            releaseTask = nil
            if handle == nil {
                handle = services.resolve(NookPresentationPinningKey.self).pin(reason: "view-modifier")
            }
        } else {
            scheduleRelease()
        }
    }

    private func scheduleRelease() {
        guard handle != nil else { return }
        releaseTask?.cancel()
        releaseTask = Task {
            try? await Task.sleep(for: NookKeepsExpandedGrace.postPresentationDuration)
            guard !Task.isCancelled else { return }
            releaseImmediately()
        }
    }

    private func releaseImmediately() {
        releaseTask?.cancel()
        releaseTask = nil
        handle?.release()
        handle = nil
    }
}
