// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim - DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import AppKit
import Combine
import SwiftUI

/// A notch-pinned floating panel with `expanded` / `compact` / `hidden` states.
///
/// Three SwiftUI view types compose the surface:
/// - `Expanded` - the full panel that drops below the menu-bar notch.
/// - `CompactLeading` - the slot to the left of the notch when collapsed.
/// - `CompactTrailing` - the slot to the right of the notch when collapsed.
///
/// Driving the lifecycle:
/// ```swift
/// let nook = Nook(style: .standard) {
///     ExpandedView()
/// } compactLeading: {
///     LeadingGlyph()
/// } compactTrailing: {
///     TrailingGlyph()
/// }
///
/// await nook.expand()
/// try await Task.sleep(for: .seconds(2))
/// await nook.compact()
/// ```
///
/// Hover side-effects are described by ``NookHoverBehavior``; opening/closing/conversion timing
/// can be customized through ``transitionConfiguration``.
///
/// `Nook` is `@MainActor`-isolated. It drives an `NSWindowController` and publishes
/// SwiftUI state, both of which are main-thread-only; the isolation makes that a
/// compiler-checked guarantee instead of a convention and lets every transition share
/// one serial generation token without a lock.
@MainActor
public final class Nook<Expanded, CompactLeading, CompactTrailing>: ObservableObject, NookControllable
where Expanded: View, CompactLeading: View, CompactTrailing: View {
    /// The chrome's window controller, or `nil` while hidden. **Internal-only** - the
    /// supported host seam for window inspection is ``hasLiveWindow``, and the
    /// supported mutation seam is ``configureWindow(_:)``. Exposing the controller
    /// publicly let hosts call `windowController?.close()` and tear the panel out
    /// from under the in-flight transition arbiter.
    var windowController: NSWindowController?

    /// `true` while the chrome has a live `NSWindow` mounted. The narrow public
    /// surface area for observing window presence - replaces the previous
    /// `windowController != nil` pattern hosts had to write.
    public var hasLiveWindow: Bool { windowController?.window != nil }

    /// Applies a configuration block to the currently-mounted `NSWindow`, if one
    /// exists. Use for window-level tweaks the framework doesn't already expose
    /// directly (e.g. an accessibility identifier, a custom window level for a niche
    /// use case). Returns `false` when the chrome is hidden and there's no live
    /// window to configure.
    ///
    /// This is the narrow supported mutation seam. The window controller itself is
    /// no longer exposed.
    @discardableResult
    public func configureWindow(_ apply: (NSWindow) -> Void) -> Bool {
        guard let window = windowController?.window else { return false }
        apply(window)
        return true
    }

    public let style: NookStyle
    public let hoverBehavior: NookHoverBehavior

    public var transitionConfiguration = NookTransitionConfiguration()

    /// Resolves the screen the chrome should occupy when a caller doesn't pass one
    /// explicitly. Host apps set this to project a persisted display preference
    /// (built-in / main / a specific display) onto the surface - the closure is
    /// consulted on every `expand`/`compact` with a `nil` screen, on hover-driven
    /// transitions, and whenever the display set changes. Returning `nil` falls
    /// through to the window's current screen, then the system's main screen.
    ///
    /// Explicitly `@MainActor`-isolated because it touches `NSScreen` and is invoked
    /// from `@MainActor` paths - the annotation makes that contract explicit to a
    /// host setting it from a non-isolated context.
    public var screenProvider: (@MainActor () -> NSScreen?)?

    /// How the chrome presents itself - notch-fused, free-floating, or `.auto` (notch on
    /// a notched display, floating elsewhere). See ``NookPresentation``.
    ///
    /// The effective layout is resolved per-window against the target screen; changing
    /// this rebuilds a currently-visible window in place so the new layout takes effect
    /// immediately. A hidden nook simply picks it up on its next `expand`/`compact`.
    public var presentation: NookPresentation = .auto {
        didSet {
            guard presentation != oldValue, state != .hidden, let screen = resolvedScreen else { return }
            rebuildVisibleWindow(on: screen)
        }
    }

    let expandedContent: Expanded
    let compactLeadingContent: CompactLeading
    let compactTrailingContent: CompactTrailing
    /// Construction-time flags set by the no-compact convenience init. Immutable so
    /// they can't be flipped mid-flight and trip the view's transition heuristics -
    /// the no-compact case is a build-time choice, not runtime state.
    let disableCompactLeading: Bool
    let disableCompactTrailing: Bool

    /// Current lifecycle state. Host apps can observe this directly (it's `@Published`)
    /// or react through the ``onExpand`` / ``onCompact`` / ``onHide`` callbacks - the
    /// callbacks fire on every transition, including hover- and drag-driven ones that
    /// never pass through a host-called `expand`/`compact`.
    @Published public private(set) var state: NookState = .hidden
    @Published private(set) var notchSize: CGSize = .zero
    @Published private(set) var menubarHeight: CGFloat = 0

    /// Layout resolved for the current window's screen - `.notch` or `.floating`.
    /// Recomputed every time the panel window is built (see `initializeWindow`); drives
    /// `NookView`'s shape and positioning.
    @Published private(set) var layoutForm: NookChromeForm = .notch
    @Published public private(set) var isHovering: Bool = false
    @Published public var staysExpandedOnHoverExit: Bool = false

    /// `true` while a layout-resize grace window is suppressing hover-exit auto-compact.
    /// Host coordinators can fold this into user-engagement signals so arbiter claims
    /// do not fire during the grace window.
    @Published public private(set) var isLayoutGraceActive: Bool = false

    /// `true` while a system file-drag session is over the panel. Drives the drop-mode UI
    /// in the expanded surface and the auto-expand from compact. The panel surfaces
    /// `NSDraggingDestination` callbacks; this published bool is the SwiftUI-friendly view.
    ///
    /// This is a derived mirror of ``dragSession`` - kept as the published surface for
    /// observers (`AppCoordinator` subscribes to `$isDragInFlight`). The authoritative
    /// session state is ``dragSession``; this bool is updated from its `didSet`.
    @Published public private(set) var isDragInFlight: Bool = false

    /// Generic drag-destination callback: invoked when AppKit drops file URLs on the panel.
    /// Returning `true` accepts the drop; `false` rejects it.
    ///
    /// This is the engine's product-agnostic seam, not a "file import" feature. The engine
    /// only does presentation-container work - it extracts URLs from the drag pasteboard,
    /// auto-expands a collapsed panel so a drop target is visible (drag-to-reveal), and
    /// hands the raw URLs to this callback. It does not interpret, store, or copy the
    /// files. Whatever the URLs *mean* - a shelf, an import flow, a no-op - is entirely the
    /// app layer's concern; the engine never sees it.
    ///
    /// `@MainActor`-isolated: invoked from the surface's main-actor drag pipeline.
    public var onFileDrop: (@MainActor ([URL]) -> Bool)?

    /// Fired when the chrome transitions **into** the expanded surface - from any source:
    /// a host-called `expand`, a hover-grow, or a file drag auto-expanding the panel.
    public var onExpand: (@MainActor () -> Void)?

    /// Fired when the chrome transitions **into** the compact pill.
    public var onCompact: (@MainActor () -> Void)?

    /// Fired when the chrome transitions **into** the hidden state. Note the cold-launch
    /// sequence collapses to compact, so `onHide` only fires on a genuine hide afterwards.
    public var onHide: (@MainActor () -> Void)?

    /// Authoritative state of the in-flight file-drag session. The whole session - the
    /// pre-drag `NookState` snapshot and whether a drag is over the panel at all - lives
    /// in this single enum so AppKit's uncoordinated enter/update/exit/end/drop callbacks
    /// cannot corrupt it (see ``DragSession``). ``isDragInFlight`` is kept in sync from
    /// the `didSet` so existing observers of that published bool are unaffected.
    var dragSession: DragSession = .idle {
        didSet {
            let inFlight: Bool
            if case .idle = dragSession { inFlight = false } else { inFlight = true }
            if isDragInFlight != inFlight { isDragInFlight = inFlight }
        }
    }

    /// What the chrome paints behind compact + expanded content - vibrancy or solid.
    @Published public var backdrop: NookBackdrop = .solidBlack

    /// Pins the chrome window's `NSAppearance`. `nil` follows the system appearance.
    ///
    /// This is the only thing that makes a forced light/dark theme render correctly: the
    /// backdrop's `NSVisualEffectView` resolves its material against the *window's*
    /// appearance, so without pinning it here a "Light" theme on a dark-mode Mac would
    /// still paint a dark frosted panel.
    ///
    /// **Deliberately not `@Published`** (unlike ``backdrop``). `NSAppearance` is an
    /// AppKit appearance proxy whose effect is the `NSWindow.appearance` set in
    /// ``didSet`` - the SwiftUI content tree re-resolves its `colorScheme` from the
    /// hosting window automatically. There is no SwiftUI observer that would benefit
    /// from a Combine publish, so adding `@Published` would be theatrical motion
    /// without behavioural change.
    public var chromeAppearance: NSAppearance? {
        didSet {
            // Pinning the appearance only pokes the live window - no rebuild - so unlike
            // `presentation` this needs no generation bump; an in-flight transition is
            // unaffected by an `NSAppearance` swap on the same window.
            windowController?.window?.appearance = chromeAppearance
        }
    }

    /// Most recent peripheral-feedback request. The view layer (`NookFeedbackOverlay`) watches
    /// this; bumping it with a new `id` re-arms the animation. Internal because callers should
    /// go through ``playFeedback(_:tint:duration:)`` rather than mutate directly.
    @Published var feedbackEvent: NookFeedbackEvent?

    /// Feedback queued while the chrome wasn't visible (`.hidden` during the boot race, or
    /// reset path). Replayed when state next transitions to `.compact`. Cleared on a real
    /// `.expanded` transition because the user has by then acknowledged the surface directly.
    private var pendingFeedback: NookFeedbackEvent?

    /// Auto-clears a one-shot `feedbackEvent` once it has finished playing. Without this the
    /// overlay's `TimelineView(.animation)` keeps ticking at 60fps forever after the cue ends
    /// (it only renders `Color.clear`, but the timeline never stops). Nilling the event lets
    /// `NookFeedbackOverlay` take its `else` branch and drop the timeline from the tree.
    /// Repeating cues are exempt - they're meant to run until acknowledged.
    private var feedbackClearTask: Task<Void, Never>?

    /// The in-flight transition - expand, compact, *or hide* - or `nil` when idle.
    /// ``runTransition(_:)`` cancels this before spawning a replacement, so a superseded
    /// transition's `Task.sleep` throws promptly instead of running to term. The hide
    /// teardown now runs as one of these tracked tasks (it used to live in a separate,
    /// untracked `closePanelTask` outside the generation system - see ``_hide(generation:)``).
    private var transitionTask: Task<Void, Never>?

    /// Monotonic transition token. ``runTransition(_:)`` bumps it **synchronously** at
    /// each entry point - hover, drag, public `expand`/`compact` - so the token reflects
    /// call order, not the order tasks happen to start running. A transition re-checks
    /// it via ``isCurrent(_:)`` at its top and after every suspension, and bails if a
    /// newer one has superseded it. This makes rapid hover-in/hover-out resolve cleanly
    /// to "the last call wins," even when the unstructured tasks start out of order.
    private var transitionGeneration = 0

    /// Auto-releases after expanded content resizes. Refreshed on each geometry change
    /// so rapid layout churn extends the grace window.
    private var layoutGraceTask: Task<Void, Never>?

    private var cancellables = Set<AnyCancellable>()

    public init(
        hoverBehavior: NookHoverBehavior = .all,
        style: NookStyle = .standard,
        @ViewBuilder expanded: @escaping () -> Expanded,
        @ViewBuilder compactLeading: @escaping () -> CompactLeading = { EmptyView() },
        @ViewBuilder compactTrailing: @escaping () -> CompactTrailing = { EmptyView() }
    ) {
        self.hoverBehavior = hoverBehavior
        self.style = style
        self.expandedContent = expanded()
        self.compactLeadingContent = compactLeading()
        self.compactTrailingContent = compactTrailing()
        self.disableCompactLeading = false
        self.disableCompactTrailing = false

        observeScreenParameters()
        observeStateForPendingFeedback()
        observeStateForLifecycleHooks()
    }

    /// Internal designated init for the no-compact-content case. The `disableCompact*`
    /// flags are stored as `let` so they can't drift at runtime - the no-compact case
    /// is a build-time choice.
    private init(
        hoverBehavior: NookHoverBehavior,
        style: NookStyle,
        expanded: @escaping () -> Expanded,
        compactLeading: @escaping () -> CompactLeading,
        compactTrailing: @escaping () -> CompactTrailing,
        disableCompactLeading: Bool,
        disableCompactTrailing: Bool
    ) {
        self.hoverBehavior = hoverBehavior
        self.style = style
        self.expandedContent = expanded()
        self.compactLeadingContent = compactLeading()
        self.compactTrailingContent = compactTrailing()
        self.disableCompactLeading = disableCompactLeading
        self.disableCompactTrailing = disableCompactTrailing

        observeScreenParameters()
        observeStateForPendingFeedback()
        observeStateForLifecycleHooks()
        observeStateForLayoutGrace()
    }

    /// Convenience for the no-compact-content case. Compact mode collapses to hide.
    public convenience init(
        hoverBehavior: NookHoverBehavior = [.keepVisible],
        style: NookStyle = .standard,
        @ViewBuilder expanded: @escaping () -> Expanded
    ) where CompactLeading == EmptyView, CompactTrailing == EmptyView {
        self.init(
            hoverBehavior: hoverBehavior,
            style: style,
            expanded: expanded,
            compactLeading: { EmptyView() },
            compactTrailing: { EmptyView() },
            disableCompactLeading: true,
            disableCompactTrailing: true
        )
    }

    var effectiveOpeningAnimation: Animation { transitionConfiguration.openingAnimation ?? style.openingAnimation }
    var effectiveClosingAnimation: Animation { transitionConfiguration.closingAnimation ?? style.closingAnimation }
    var effectiveConversionAnimation: Animation {
        transitionConfiguration.conversionAnimation ?? style.conversionAnimation
    }

    /// When the chrome becomes visible (state transitions out of `.hidden`), replay any
    /// feedback that was requested during the boot race. Single sink keeps lifetime tied
    /// to `Nook`'s cancellables; no unstructured tasks.
    private func observeStateForPendingFeedback() {
        $state
            .removeDuplicates()
            .sink { [weak self] newState in
                guard let self, newState != .hidden, let pending = self.pendingFeedback else { return }
                self.pendingFeedback = nil
                self.setFeedbackEvent(pending)
            }
            .store(in: &cancellables)
    }

    /// Fire the host's lifecycle callbacks on every distinct state transition. A single
    /// `$state` sink catches transitions from *all* sources uniformly - host-called
    /// `expand`/`compact`, hover-driven grow/shrink, drag auto-expand - which is why the
    /// hooks live here rather than on a higher-level coordinator. `dropFirst()` skips the
    /// initial `.hidden` published at construction; `removeDuplicates()` collapses no-op
    /// re-publishes so a hook never double-fires for one logical transition.
    private func observeStateForLifecycleHooks() {
        $state
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newState in
                guard let self else { return }
                switch newState {
                    case .expanded: self.onExpand?()
                    case .compact: self.onCompact?()
                    case .hidden: self.onHide?()
                }
            }
            .store(in: &cancellables)
    }

    /// Clears layout grace when the surface leaves `.expanded` so a compact/hidden nook
    /// does not inherit a stale suppression window.
    private func observeStateForLayoutGrace() {
        $state
            .removeDuplicates()
            .sink { [weak self] newState in
                guard let self, newState != .expanded else { return }
                self.endLayoutGrace()
            }
            .store(in: &cancellables)
    }

    /// The screen the chrome should occupy when no explicit screen is supplied.
    /// Consults the host-supplied ``screenProvider`` first, then the window's current
    /// screen, then the system. `nil` only when no display is attached at all.
    var resolvedScreen: NSScreen? {
        screenProvider?()
            ?? windowController?.window?.screen
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    /// Re-place the panel on screen-parameter changes (display add/remove, resolution
    /// or arrangement changes). Combine sink keeps the observer's lifetime tied to
    /// `Nook` and frees us from an unstructured `Task` whose cancellation we never
    /// wired up.
    ///
    /// While hidden there's no window worth keeping - drop any stale one so the next
    /// `expand`/`compact` rebuilds on the then-current preferred screen. While visible,
    /// recompute the target via ``resolvedScreen`` and re-show there, so a host's
    /// display preference (and its disconnect fallback) follows the chrome live.
    private func observeScreenParameters() {
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                guard self.state != .hidden else {
                    // No window worth keeping while hidden. Supersede any in-flight
                    // transition first so a mid-flight `_expand`/`_compact`/`_hide`
                    // can't keep operating on the window we're about to tear down.
                    self.supersedeInFlightTransition()
                    self.deinitializeWindow()
                    return
                }
                guard let screen = self.resolvedScreen else { return }
                self.rebuildVisibleWindow(on: screen)
            }
            .store(in: &cancellables)
    }

    /// Notifies the surface that expanded content geometry changed. Called from
    /// ``NookView`` when the expanded body resizes; acquires a short-lived grace
    /// window that suppresses hover-exit auto-compact while layout settles.
    func noteExpandedContentSizeChange() {
        guard state == .expanded else { return }
        beginLayoutGrace()
    }

    /// Apply hover side-effects (haptic, expand-on-hover, collapse-on-exit).
    func updateHoverState(_ hovering: Bool) {
        guard state != .hidden, hovering != isHovering else { return }

        isHovering = hovering

        if hoverBehavior.contains(.hapticFeedback) {
            let performer = NSHapticFeedbackManager.defaultPerformer
            performer.perform(.alignment, performanceTime: .default)
        }

        guard hovering || !suppressesHoverExitCompact else {
            return
        }

        guard let screen = windowController?.window?.screen ?? resolvedScreen else { return }
        runTransition { [weak self] generation in
            guard let self else { return }
            if hovering {
                await self._expand(on: screen, skipHide: true, generation: generation)
            } else {
                await self._compact(on: screen, skipHide: true, generation: generation)
            }
        }
    }

    /// Claims the next transition generation **synchronously**, cancels any in-flight
    /// transition, and runs `body` as the sole tracked transition task. `body` receives
    /// its generation and must re-check ``isCurrent(_:)`` at its top and after every
    /// suspension. The returned task completes when `body` does, so an `await`ing caller
    /// (e.g. `expand()`) sees the transition through to settle.
    ///
    /// Every transition - expand, compact, **and hide** - flows through here, so a new
    /// transition reliably supersedes whatever was in flight: the generation bump fails
    /// the predecessor's next `isCurrent` check, and the `cancel()` stops it sleeping.
    /// In particular a hover- or drag-driven `expand` cancels an in-flight hide's
    /// teardown before it can deinit the window out from under the freshly-expanded
    /// surface.
    @discardableResult
    func runTransition(_ body: @escaping @MainActor (_ generation: Int) async -> Void) -> Task<Void, Never> {
        transitionGeneration &+= 1
        let generation = transitionGeneration
        transitionTask?.cancel()
        let task = Task { @MainActor [weak self] in
            await body(generation)
            // Only clear the handle if no newer transition has replaced it.
            if let self, self.transitionGeneration == generation { self.transitionTask = nil }
        }
        transitionTask = task
        return task
    }

    /// `true` while `generation` is still the most recent transition - i.e. no newer
    /// `expand`/`compact`/`hide` has been claimed since.
    func isCurrent(_ generation: Int) -> Bool { transitionGeneration == generation }

    /// Claim a fresh transition generation **synchronously** and cancel any in-flight
    /// transition, without spawning a replacement.
    ///
    /// Used by the synchronous window-swap paths (`presentation.didSet`, the
    /// screen-parameter observer) which rebuild or drop the window outside of
    /// `runTransition`. Bumping the generation here is the supersession signal: a
    /// mid-flight `_expand`/`_compact`/`_hide` re-checks `isCurrent` after each
    /// suspension and bails the instant the window is rebuilt under it, rather than
    /// animating (or deinit'ing) a window that has already been swapped.
    func supersedeInFlightTransition() {
        transitionGeneration &+= 1
        transitionTask?.cancel()
        transitionTask = nil
    }

    /// Rebuild a currently-visible window in place (new screen, new presentation) so the
    /// new layout takes effect immediately. Supersedes any in-flight transition first so
    /// it can't keep mutating the window being swapped - see ``supersedeInFlightTransition()``.
    func rebuildVisibleWindow(on screen: NSScreen) {
        supersedeInFlightTransition()
        initializeWindow(screen: screen, orderFront: false)
        showWindow()
    }
}

// MARK: - Public lifecycle

extension Nook {
    /// Expand the chrome. Pass `nil` (the default) to let ``resolvedScreen`` pick the
    /// target - typically the host's persisted display preference via ``screenProvider``.
    public func expand(on screen: NSScreen? = nil) async {
        guard let target = screen ?? resolvedScreen else { return }
        let skipHide = transitionConfiguration.skipIntermediateHides
        await runTransition { [weak self] generation in
            await self?._expand(on: target, skipHide: skipHide, generation: generation)
        }.value
    }

    /// Collapse the chrome to its compact pill. Pass `nil` (the default) to let
    /// ``resolvedScreen`` pick the target.
    public func compact(on screen: NSScreen? = nil) async {
        guard let target = screen ?? resolvedScreen else { return }
        let skipHide = transitionConfiguration.skipIntermediateHides
        await runTransition { [weak self] generation in
            await self?._compact(on: target, skipHide: skipHide, generation: generation)
        }.value
    }

    /// Hide the chrome and tear the window down. Routed through ``runTransition(_:)`` -
    /// exactly like `expand`/`compact` - so the hide and its teardown live fully inside
    /// the generation system: a newer transition reliably supersedes an in-flight hide,
    /// cancelling its task before its `fadeOutWindow`/`deinitializeWindow` can run.
    public func hide() async {
        await runTransition { [weak self] generation in
            await self?._hide(generation: generation)
        }.value
    }
}

// MARK: - Peripheral feedback

extension Nook {
    /// Play a one-shot peripheral cue along the chrome's perimeter. Default is the shimmer sweep.
    ///
    /// Use this for low-priority "something happened" signals the user can catch in
    /// peripheral vision - a sync finished, a background task completed. Caller-owned
    /// timing - no internal queueing or debouncing; rapid successive calls re-anchor
    /// `startedAt` and the in-flight animation restarts. A cue requested while the chrome
    /// is hidden is queued and replayed the next time the nook becomes visible.
    public func playFeedback(
        _ effect: NookFeedback = .shimmer,
        tint: Color = Color(nsColor: .controlAccentColor),
        duration: TimeInterval = 0.85,
        repeats: Bool = false
    ) {
        guard effect != .none else { return }
        let event = NookFeedbackEvent(
            id: UUID(),
            startedAt: Date(),
            effect: effect,
            duration: duration,
            tint: tint,
            respectsReduceMotion: true,
            repeats: repeats
        )
        switch state {
            case .compact, .expanded:
                // Chrome is visible (either as compact pill or expanded surface) - fire
                // immediately. The shimmer overlay strokes the same `NookShape` perimeter in
                // both states, so the visual reads on either.
                setFeedbackEvent(event)
                pendingFeedback = nil
            case .hidden:
                // Boot race or user-hidden: queue for the next visible transition. The overlay
                // can't paint without chrome, but we don't want to drop the request entirely
                // because the cue's whole job is "tell the user when they're not looking."
                pendingFeedback = event
        }
    }
}

extension Nook {
    /// Publishes `event` to the overlay and, for one-shot cues, arms a clear once the cue has
    /// finished so the overlay's `TimelineView` is torn down instead of ticking forever. Any
    /// prior pending clear is cancelled first so a fresh event always wins.
    func setFeedbackEvent(_ event: NookFeedbackEvent) {
        feedbackClearTask?.cancel()
        feedbackEvent = event

        guard !event.repeats, event.duration > 0 else { return }
        let duration = event.duration
        let id = event.id
        feedbackClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            // Only clear if this is still the event we armed for - a newer cue (which cancels
            // this task) or a repeating cue must not be nilled out from under the overlay.
            if self.feedbackEvent?.id == id { self.feedbackEvent = nil }
            self.feedbackClearTask = nil
        }
    }
}

extension Nook {
    /// Expand the chrome onto `screen`. Runs on the main actor and `await`s the
    /// transition to completion - including a settle pass that lets the open or
    /// conversion animation finish - so an awaited `expand()` returns once the chrome
    /// has visibly arrived, not after an unrelated fixed delay.
    ///
    /// `generation` is the token claimed synchronously by ``runTransition(_:)``. The
    /// method bails the instant a newer transition supersedes it: at its top (covering
    /// a task that was queued but overtaken before it ran) and after each suspension.
    func _expand(on screen: NSScreen, skipHide: Bool, generation: Int) async {
        // Superseded before this task even started running.
        guard isCurrent(generation) else { return }

        // Opening the nook acknowledges any *repeating* peripheral cue - those are
        // meant to keep nagging until the user looks, so once they're looking we kill
        // them. A one-shot cue (e.g. the launch shimmer greeting) is allowed to play
        // through the expand transition so the user actually sees it; the perimeter
        // stroke renders on expanded chrome just as well as on compact.
        //
        // This runs BEFORE the same-screen early return below: a second `expand()`
        // on an already-expanded surface still acknowledges the cue. The earlier
        // ordering returned without clearing, so a repeating shimmer kept nagging
        // after a same-screen re-expand.
        if feedbackEvent?.repeats == true { feedbackEvent = nil }
        if pendingFeedback?.repeats == true { pendingFeedback = nil }

        // Already expanded *on the requested screen* - nothing to do. A different
        // screen still needs work: the window must move, so fall through to the
        // rebuild path, which `needsNewWindow` below already handles.
        if state == .expanded, windowController?.window?.screen == screen { return }

        let needsNewWindow = state == .hidden || windowController?.window?.screen != screen

        if needsNewWindow {
            initializeWindow(screen: screen, orderFront: false)
            withAnimation(effectiveOpeningAnimation) { state = .expanded }
            showWindow()
            try? await Task.sleep(for: openSettleDuration)
            // A screen-parameter change during the settle could have rebuilt the
            // window underneath us; bail rather than return success on a defunct view.
            // `Task.isCancelled` belt-and-suspenders matches `_hide`'s pattern - a
            // cancellation can only come from a generation-bumping supersession today,
            // so this is redundant with `isCurrent`, but the two together make the
            // bail condition robust against any future cancellation path.
            guard isCurrent(generation), !Task.isCancelled else { return }
        } else {
            if !skipHide {
                withAnimation(effectiveClosingAnimation) { state = .hidden }
                try? await Task.sleep(for: intermediateHideDuration)
                // A newer transition may have superseded us across the sleep.
                guard isCurrent(generation), !Task.isCancelled, state == .hidden else { return }
            }
            withAnimation(effectiveConversionAnimation) { state = .expanded }
            try? await Task.sleep(for: conversionSettleDuration)
            guard isCurrent(generation), !Task.isCancelled else { return }
        }
    }

    /// Collapse the chrome to its compact pill on `screen`. Like ``_expand(on:skipHide:generation:)``
    /// it runs on the main actor, `await`s the transition to completion, and bails on
    /// supersession by re-checking `generation`.
    func _compact(on screen: NSScreen, skipHide: Bool, generation: Int) async {
        guard isCurrent(generation) else { return }

        if disableCompactLeading, disableCompactTrailing {
            // No compact content to show - "compact" collapses to a full hide. Run the
            // hide *inline on this same generation* rather than calling the public
            // `hide()`: the latter claims a fresh generation via `runTransition` and
            // would supersede the very transition we're inside, dropping our teardown.
            await _hide(generation: generation)
            return
        }

        // Already compact *on the requested screen* - nothing to do. A different
        // screen still needs the window moved, so fall through to the rebuild path.
        if state == .compact, windowController?.window?.screen == screen { return }

        let needsNewWindow = state == .hidden || windowController?.window?.screen != screen

        if needsNewWindow {
            initializeWindow(screen: screen, orderFront: false)
            withAnimation(effectiveOpeningAnimation) { state = .compact }
            showWindow()
            try? await Task.sleep(for: openSettleDuration)
            guard isCurrent(generation), !Task.isCancelled else { return }
        } else {
            if !skipHide {
                withAnimation(effectiveClosingAnimation) { state = .hidden }
                try? await Task.sleep(for: intermediateHideDuration)
                guard isCurrent(generation), !Task.isCancelled, state == .hidden else { return }
            }
            withAnimation(effectiveConversionAnimation) { state = .compact }
            try? await Task.sleep(for: conversionSettleDuration)
            guard isCurrent(generation), !Task.isCancelled else { return }
        }
    }

    /// Hide the chrome and tear the window down. Runs as a tracked transition under
    /// ``runTransition(_:)`` - `generation` is the token it claimed synchronously.
    ///
    /// Because the hide now lives fully inside the generation system, every step
    /// re-checks ``isCurrent(_:)`` after each suspension point: a newer transition
    /// (a hover-grow, a drag auto-expand, a host `expand`) bumps the generation and
    /// cancels this task via `runTransition`, so the teardown - `keepVisible` poll,
    /// intermediate-hide dwell, `fadeOutWindow`, `deinitializeWindow` - bails before it
    /// can deinit a window the newer transition has already claimed. Previously this
    /// teardown ran in an untracked `closePanelTask` outside the generation system, so a
    /// hover-grow racing it could have the window deinit'd out from under a
    /// freshly-expanded surface.
    ///
    /// `.keepVisible` still defers the hide until the cursor leaves the panel, but the
    /// poll is now part of this awaited transition rather than a recursively-spawned
    /// untracked task - an awaited `hide()` always resolves: cursor leaves, supersession,
    /// task cancellation, or already-hidden.
    func _hide(generation: Int) async {
        // Superseded before this task even started running.
        guard isCurrent(generation) else { return }
        guard state != .hidden else { return }

        // `.keepVisible` defers an explicit hide until the cursor leaves the panel - we
        // don't yank the surface out from under an active hover. Poll inline; bail if a
        // newer transition supersedes us, or if hover behavior stops requesting deferral.
        if hoverBehavior.contains(.keepVisible), isHovering {
            while isCurrent(generation), isHovering,
                hoverBehavior.contains(.keepVisible), !Task.isCancelled
            {
                try? await Task.sleep(for: Self.keepVisiblePollInterval)
            }
            // Superseded (or cancelled) while waiting for the cursor to leave: a newer
            // transition owns the surface now - do not tear its window down.
            guard isCurrent(generation), !Task.isCancelled else { return }
            // A superseded-then-restored race could have left us already hidden.
            guard state != .hidden else { return }
        }

        withAnimation(effectiveClosingAnimation) {
            state = .hidden
            isHovering = false
        }

        try? await Task.sleep(for: intermediateHideDuration)
        // A newer transition took over across the close-animation dwell - it owns the
        // window now, so skip the teardown entirely.
        guard isCurrent(generation), !Task.isCancelled else { return }

        await fadeOutWindow()
        guard isCurrent(generation), !Task.isCancelled else { return }

        deinitializeWindow()
    }

    /// Mask any closing-frame artifacts behind a brief layer-opacity fade before tearing the window down.
    /// Animating the hosting layer (not `NSWindow.alphaValue`) keeps shadow and vibrancy compositing
    /// independent of the fade, and runs entirely on the compositor.
    @MainActor
    private func fadeOutWindow() async {
        guard let layer = hostingLayer else { return }

        await withCheckedContinuation { continuation in
            CATransaction.begin()
            CATransaction.setCompletionBlock {
                continuation.resume()
            }
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = layer.presentation()?.opacity ?? layer.opacity
            animation.toValue = 0
            animation.duration = Self.fadeDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeIn)
            layer.add(animation, forKey: "nook.opacity")
            layer.opacity = 0
            CATransaction.commit()
        }
    }
}

// MARK: - Window management

extension Nook {
    /// Duration of the hosting-layer fade used during show/teardown.
    static var fadeDuration: CFTimeInterval { 0.15 }

    /// Nominal duration of the built-in open/close/conversion animations (see
    /// ``NookStyle``). The default settle allowances below are sized to this; a host
    /// overriding the curves declares its own duration via
    /// ``NookTransitionConfiguration/animationDuration``.
    static var defaultAnimationDuration: TimeInterval { 0.4 }

    /// The animation duration the settle allowances should be sized to: the host's
    /// declared ``NookTransitionConfiguration/animationDuration`` when set, otherwise
    /// the built-in default. This is what makes an awaited `expand()`/`compact()` honor
    /// its "returns once the chrome has visibly arrived" contract for *any* configured
    /// animation, not just the default-speed one.
    var settleAnimationDuration: TimeInterval {
        max(transitionConfiguration.animationDuration ?? Self.defaultAnimationDuration, 0)
    }

    /// Settle allowance after a fresh open animation (`.hidden` -> visible) before an
    /// awaited `expand()`/`compact()` returns.
    ///
    /// SwiftUI's `Animation` exposes no portable duration accessor, so the surface cannot
    /// time the chrome's visible arrival from the animation itself. Instead the
    /// settle delay is derived from the *configured* animation duration
    /// (``settleAnimationDuration``) plus a fixed cushion for the window-show fade - so
    /// the await contract holds whether the host keeps the default curves or supplies a
    /// slower custom animation. Sized to match the previous 550 ms constant at the
    /// default 0.4 s duration.
    var openSettleDuration: Duration {
        .seconds(settleAnimationDuration + Self.fadeDuration)
    }

    /// Settle allowance after a compact ⇄ expanded conversion animation. Like
    /// ``openSettleDuration`` but without the window-show cushion (the window is already
    /// visible). Equal to the configured animation duration; matches the previous
    /// 300 ms constant once that constant's ~100 ms slack over a 0.4 s spring is folded
    /// into "let the spring settle."
    var conversionSettleDuration: Duration {
        .seconds(settleAnimationDuration)
    }

    /// Dwell at `.hidden` between a close animation and the following conversion (or
    /// teardown), when intermediate hides are not skipped. A partial dwell of the
    /// closing animation - the chrome need not be fully gone before the next phase
    /// starts. Sized to match the previous 250 ms constant at the default 0.4 s duration.
    var intermediateHideDuration: Duration {
        .seconds(settleAnimationDuration * 0.625)
    }

    /// Poll cadence for a `.keepVisible` hide deferred until the cursor leaves.
    static var keepVisiblePollInterval: Duration { .milliseconds(100) }

    /// Default grace after expanded content resizes before hover-exit auto-compact resumes.
    static var defaultLayoutGraceDuration: TimeInterval { 0.6 }

    /// Effective layout-grace duration from ``NookTransitionConfiguration/layoutGraceDuration``.
    var layoutGraceDuration: Duration {
        let seconds = max(
            transitionConfiguration.layoutGraceDuration ?? Self.defaultLayoutGraceDuration,
            0
        )
        return .seconds(seconds)
    }

    /// Hover-exit auto-compact is suppressed while a presentation pin or layout grace is active.
    var suppressesHoverExitCompact: Bool {
        staysExpandedOnHoverExit || isLayoutGraceActive
    }

    func beginLayoutGrace() {
        layoutGraceTask?.cancel()
        isLayoutGraceActive = true
        let duration = layoutGraceDuration
        layoutGraceTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard let self, !Task.isCancelled else { return }
            self.isLayoutGraceActive = false
            self.layoutGraceTask = nil
        }
    }

    func endLayoutGrace() {
        layoutGraceTask?.cancel()
        layoutGraceTask = nil
        if isLayoutGraceActive { isLayoutGraceActive = false }
    }

    /// The layer of the hosting view inside the panel. Layer-level fades run here so the
    /// `NSWindow` itself (and its shadow/vibrancy compositing) stays at full alpha.
    ///
    /// Pure: `wantsLayer` is set once in `initializeWindow`, so this is just a lookup.
    var hostingLayer: CALayer? {
        windowController?.window?.contentView?.layer
    }
}

extension Nook {
    fileprivate func initializeWindow(screen: NSScreen, orderFront: Bool = true) {
        deinitializeWindow()

        notchSize = screen.notchFrameWithMenubarAsBackup.size
        menubarHeight = screen.menubarHeight
        layoutForm = presentation.isFloating(screenHasNotch: screen.hasNotch) ? .floating : .notch

        // Two modifiers used to live on a `NookContentView` shim: a full-bleed
        // top-anchored frame and a conversion animation on hover. Inlining the
        // shim removes a one-line passthrough that earned its keep only as a
        // named type - `NSHostingView` is the only consumer.
        let rootView = NookView(nook: self)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(effectiveConversionAnimation, value: isHovering)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Drag-receiving overlay sits on top of the SwiftUI hosting view so file-drag
        // events reach us before `NSHostingView` consumes them. It's hit-test-transparent
        // (returns nil) so pointer interactions pass through unchanged.
        let dragInterceptor = NookDragInterceptingView()
        dragInterceptor.wantsLayer = true
        dragInterceptor.dragDestination = self
        dragInterceptor.translatesAutoresizingMaskIntoConstraints = false

        // Plain container holds both as siblings; the interceptor is added last so it
        // sits above the hosting view in the subview list (and therefore in z-order).
        let container = NSView()
        container.wantsLayer = true
        container.addSubview(hostingView)
        container.addSubview(dragInterceptor)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dragInterceptor.topAnchor.constraint(equalTo: container.topAnchor),
            dragInterceptor.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            dragInterceptor.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dragInterceptor.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        let panel = NookPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.contentView = container
        panel.appearance = chromeAppearance

        let size = NSSize(
            width: screen.frame.width,
            height: screen.frame.height / 2
        )
        let origin = NSPoint(
            x: screen.frame.midX - (size.width / 2),
            y: screen.frame.maxY - size.height
        )

        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        panel.layoutIfNeeded()

        if orderFront {
            panel.orderFrontRegardless()
        }

        windowController = .init(window: panel)
    }

    /// Show with the hosting layer starting at opacity 0, then animate to 1. The window itself
    /// is at full alpha - only the SwiftUI content fades in, masking any first-frame layout pop.
    fileprivate func showWindow() {
        guard let window = windowController?.window else { return }

        let layer = hostingLayer
        layer?.opacity = 0

        window.orderFrontRegardless()

        // Re-pin a forced appearance now that the window is on screen. The macOS 26 Liquid Glass
        // material binds its light/dark rendering when the hosting view first appears, and does not
        // re-resolve when `window.appearance` was pinned before it was visible (as it is at window
        // creation in `initializeWindow`). A cold launch in a forced Light or Dark theme otherwise
        // paints a stale, system-appearance glass until the user toggles the theme by hand. Flipping
        // the appearance off and back on the next runloop - while the content is still faded to zero
        // below - reproduces that manual toggle so the glass adopts the pinned scheme unseen. No-op
        // when following the Mac (nil), where the system appearance is already correct.
        if let forcedAppearance = chromeAppearance {
            DispatchQueue.main.async { [weak window] in
                window?.appearance = nil
                DispatchQueue.main.async { [weak window] in
                    window?.appearance = forcedAppearance
                }
            }
        }

        guard let layer else { return }

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = Self.fadeDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: "nook.opacity")
        layer.opacity = 1
    }

    fileprivate func deinitializeWindow() {
        guard let windowController else { return }
        windowController.close()
        self.windowController = nil
    }
}

// The drag-session state machine and `NookDragDestination` conformance live in
// `Internal/Nook+Drag.swift` - kept out of this file so Nook.swift stays focused
// on lifecycle/transition concerns. The stored `dragSession` property is declared
// above (on `Nook` itself); the surrounding state machine and the destination
// conformance are the extracted pieces.
