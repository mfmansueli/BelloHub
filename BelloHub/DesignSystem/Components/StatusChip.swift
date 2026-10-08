//
//  StatusChip.swift
//  BelloHub
//

import SwiftUI

/// A 26 pt capsule with a 6 pt dot and a word. Always a word, never color alone.
struct StatusChip: View {
    let label: LocalizedStringKey
    let style: StatusStyle

    var body: some View {
        HStack(spacing: Spacing.xs + Spacing.xxs) {
            Circle().fill(style.dot).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(style.foreground)
        }
        .padding(.horizontal, Spacing.row)
        .frame(minHeight: 26)
        .background(style.background, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
