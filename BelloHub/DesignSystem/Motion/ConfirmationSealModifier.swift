//
//  ConfirmationSealModifier.swift
//  BelloHub
//

import SwiftUI

/// A brief `SuccessSeal` over the top of a screen when something finishes, with its success haptic. It never takes
/// a touch (`allowsHitTesting(false)`), so the next action is tappable at once, and it is hidden from VoiceOver
/// because the screen's own text already says what happened. Fires only when the trigger moves the right way
/// (`ConfirmationCue`), never for the value a screen starts with.
private struct ConfirmationSealModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    let fires: (Trigger, Trigger) -> Bool
    @State private var shown = false
    @State private var playCount = 0
    @Environment(\.motionPolicy) private var policy

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if shown {
                    SuccessSeal(size: 56)
                        .padding(.top, Spacing.lg)
                        .id(playCount)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: trigger) { old, new in
                guard fires(old, new) else { return }
                playCount += 1
                withAnimation(MotionChange.animation(.fade, policy: policy)) { shown = true }
            }
            .task(id: playCount) {
                guard playCount > 0 else { return }
                try? await Task.sleep(for: .seconds(ConfirmationCue.sealHold))
                guard !Task.isCancelled else { return }
                withAnimation(MotionChange.animation(.fade, policy: policy)) { shown = false }
            }
    }
}

extension View {
    /// Shows the brief seal when `count` goes up (a photo saved, a message marked as sent).
    func confirmationSeal(whenIncreases count: Int) -> some View {
        modifier(ConfirmationSealModifier(trigger: count, fires: { ConfirmationCue.fires(countFrom: $0, to: $1) }))
    }

    /// Shows the brief seal when `flag` turns on (a request confirmed).
    func confirmationSeal(whenTrue flag: Bool) -> some View {
        modifier(ConfirmationSealModifier(trigger: flag, fires: { ConfirmationCue.fires(flagFrom: $0, to: $1) }))
    }
}
