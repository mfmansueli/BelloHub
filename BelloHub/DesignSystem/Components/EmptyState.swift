//
//  EmptyState.swift
//  BelloHub
//

import SwiftUI

/// Two or three overlapping tinted shapes and one symbol, a title, one line saying what to do next and
/// at most one primary action. Every list and every screen that loads data defines this state.
struct EmptyState: View {
    let icon: Icon
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.md) {
            illustration
            Text(title)
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(Typography.meta)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle) }
                    .buttonStyle(.belloPrimary)
                    .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var illustration: some View {
        ZStack {
            Circle().fill(Palette.roseWash).frame(width: 84, height: 84).directionalOffset(x: -18, y: 6)
            Circle().fill(Palette.sageWash).frame(width: 64, height: 64).directionalOffset(x: 22, y: -8)
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(Palette.peachWash).frame(width: 56, height: 56).directionalOffset(x: 4, y: 20)
            Image(icon: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Palette.roseDeepText)
        }
        .frame(height: 110)
        .accessibilityHidden(true)
    }
}
