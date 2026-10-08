//
//  StepProgressBar.swift
//  BelloHub
//

import SwiftUI

/// One segment per step, filled up to the current one. Spoken as "Step 2 of 6": the segments themselves are
/// decorative.
struct StepProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(1...max(total, 1), id: \.self) { step in
                Capsule()
                    .fill(step <= current ? Palette.ink : Palette.hairline)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            LocalizedStringResource("common.stepProgress", defaultValue: "Step \(current) of \(total)")
        ))
    }
}
