// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Kai Azim — DynamicNotchKit (original)
// Copyright (c) 2026 Glendon Chin — OpenNook modifications
//
// Licensed under the MIT License.
// Original kit license: /ThirdPartyLicenses/DynamicNotchKit.txt
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

/// Plays a one-shot peripheral animation along the chrome's perimeter when ``Nook/feedbackEvent``
/// is set.
///
/// Implementation strategy: a `TimelineView` advances `progress = (now − startedAt) / duration`
/// in the 0...1 range. The shimmer is a `LinearGradient` whose `startPoint` / `endPoint` slide
/// across the unit square so a 0.5-unit-wide bright band moves from off-screen leading to
/// off-screen trailing — masked onto a stroked ``NookShape`` so only the chrome's perimeter
/// receives light. Once `progress` hits 1 the overlay renders `Color.clear`; the model then
/// nils ``Nook/feedbackEvent`` (see ``Nook/setFeedbackEvent(_:)``) so this whole branch — and
/// its `TimelineView` — drops from the view tree until the next event lands. Repeating cues
/// keep the timeline alive by design.
///
/// Because the animation is a pure function of `(now, startedAt, duration)`, no `@State`
/// reset choreography is needed when a new event preempts an in-flight one — bumping
/// ``Nook/feedbackEvent`` re-anchors `startedAt` and the gradient picks up at progress 0
/// the next frame.
///
/// Composition note: this view is inserted **before** the `.compositingGroup() + .clipShape()`
/// in ``NookView`` so the stroke is part of the same flatten group as backdrop + content,
/// then carved by the notch shape together. `.blendMode(.plusLighter)` keeps the highlight
/// reading as added light against the dark backdrop without overdarkening on light themes.
struct NookFeedbackOverlay: View {
    let event: NookFeedbackEvent?
    let form: NookChromeForm
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let reduceMotion: Bool

    var body: some View {
        if let event {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
                let elapsed = context.date.timeIntervalSince(event.startedAt)
                let progress = progressValue(for: event, elapsed: elapsed)
                if progress < 1 {
                    overlayContent(event: event, progress: progress)
                } else {
                    Color.clear
                }
            }
            .allowsHitTesting(false)
        } else {
            Color.clear
        }
    }

    /// One-shot events advance linearly and clamp at 1. Repeating events wrap with modulo so
    /// the animation reaches `progress=1` (the natural fade-out point of each cycle), rolls
    /// back to 0, and starts again — every iteration is visually identical to the first.
    private func progressValue(for event: NookFeedbackEvent, elapsed: TimeInterval) -> Double {
        guard event.duration > 0 else { return 1 }
        if event.repeats {
            let phase = elapsed.truncatingRemainder(dividingBy: event.duration)
            return max(phase / event.duration, 0)
        }
        return min(max(elapsed / event.duration, 0), 1)
    }

    @ViewBuilder
    private func overlayContent(event: NookFeedbackEvent, progress: Double) -> some View {
        if reduceMotion && event.respectsReduceMotion {
            saturationCrossfade(event: event, progress: progress)
        } else {
            shimmerSweep(event: event, progress: progress)
        }
    }

    /// Sweeps a 0.5-unit-wide bright band from off-screen leading to off-screen trailing.
    ///
    /// Math: `startPoint.x = -0.5 + p · 1.5`, `endPoint.x = startPoint.x + 0.5`. At p=0 the
    /// band is just off-screen left (start=-0.5, end=0); at p=0.5 it's centered (0.25, 0.75);
    /// at p=1 it's just off-screen right (1.0, 1.5). Total travel = 1.5 unit-widths in
    /// `duration` seconds.
    ///
    /// `envelope = sin(p · π)` ramps the overall opacity 0 → 1 → 0 over the same window so the
    /// band fades in as it enters the visible region and fades out as it leaves — no hard
    /// edges at the start/end frames.
    private func shimmerSweep(event: NookFeedbackEvent, progress: Double) -> some View {
        let startX = -0.5 + progress * 1.5
        let endX = startX + 0.5
        let envelope = sin(progress * .pi)

        let highlight = event.tint.opacity(0.95)
        let core = Color.white.opacity(0.75)
        let gradient = LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: highlight, location: 0.42),
                .init(color: core, location: 0.5),
                .init(color: highlight, location: 0.58),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: UnitPoint(x: startX, y: 0.5),
            endPoint: UnitPoint(x: endX, y: 0.5)
        )

        return ZStack {
            // Soft ambient halo that pulses with the shimmer — gives the perimeter weight at
            // peripheral vision so the cue reads even when the user isn't directly looking.
            NookShape(form: form, topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
                .stroke(event.tint.opacity(0.55), lineWidth: 8.0)
                .blur(radius: 3.0)
                .opacity(envelope * 0.9)
                .blendMode(.plusLighter)

            NookShape(form: form, topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
                .stroke(gradient, lineWidth: 6.0)
                .opacity(envelope)
                .blendMode(.plusLighter)
        }
    }

    /// Reduce Motion fallback. No horizontal sweep; the perimeter pulses the tint color in and
    /// out symmetrically. Functionally informative ("the chrome briefly accented") without the
    /// vestibular cost of moving content.
    private func saturationCrossfade(event: NookFeedbackEvent, progress: Double) -> some View {
        let envelope = sin(progress * .pi) * 0.7
        return NookShape(form: form, topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
            .stroke(event.tint, lineWidth: 4.0)
            .opacity(envelope)
            .blendMode(.plusLighter)
    }

}
