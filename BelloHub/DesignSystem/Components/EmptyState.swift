//
//  EmptyState.swift
//  BelloHub
//

import SwiftUI

/// Two or three overlapping shapes in the brand illustration fills and one symbol, a title, one line saying what to do
/// next and at most one primary action. Every list and every screen that loads data defines this state.
struct EmptyState: View {
    let icon: Icon
    let title: Text
    let message: Text
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    init(
        icon: Icon, title: LocalizedStringKey, message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil
    ) {
        self.init(icon: icon, title: Text(title), message: Text(message), actionTitle: actionTitle, action: action)
    }

    /// For a title or a message with an argument (`Text(LocalizedStringResource(...))`), which a key cannot carry.
    init(icon: Icon, title: Text, message: Text, actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            illustration
            title
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            message
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
            Circle().fill(Palette.roseFill).frame(width: 84, height: 84).directionalOffset(x: -18, y: 6)
            Circle().fill(Palette.sageFill).frame(width: 64, height: 64).directionalOffset(x: 22, y: -8)
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(Palette.peachFill).frame(width: 56, height: 56).directionalOffset(x: 4, y: 20)
            Image(icon: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Palette.roseDeepText)
        }
        .frame(height: 110)
        .accessibilityHidden(true)
    }
}
