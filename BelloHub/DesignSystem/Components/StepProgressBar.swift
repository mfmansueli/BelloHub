//
//  StepProgressBar.swift
//  BelloHub
//

import SwiftUI

/// One segment per step, filled up to the current one. Spoken as "Step 2 of 6": the segments themselves are
/// decorative. The spoken element is a 44 pt tall overlay, so VoiceOver's focus is a reachable target although the bar
/// is 4 pt (the accessibility audit's hit-region check).
struct StepProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(1...max(total, 1), id: \.self) { step in
                Capsule()
                    .fill(step <= current ? Palette.action : Palette.hairline)
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
        .overlay {
            Color.clear
                .frame(height: Spacing.touchTarget)
                .accessibilityElement()
                .accessibilityLabel(Text(
                    LocalizedStringResource("common.stepProgress", defaultValue: "Step \(current) of \(total)")
                ))
        }
    }
}
