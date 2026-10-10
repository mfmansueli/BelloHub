//
//  ChoiceCard.swift
//  BelloHub
//

import SwiftUI

/// A card she taps to switch a choice on or off: a profession, a suggested service. Selected cards are raised with
/// an ink outline and a check; the others sit flat. Reads as one element ("Esthetician, selected").
struct ChoiceCard: View {
    let title: String
    var subtitle: String?
    /// Draws the subtitle in the accent color, for a line that says "this one is yours".
    var emphasizesSubtitle = false
    let isSelected: Bool
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.row) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: title)
                        .font(Typography.bodyStrong)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(verbatim: subtitle)
                            .font(Typography.meta)
                            .foregroundStyle(emphasizesSubtitle ? Palette.roseText : Palette.ink2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: Spacing.sm)
                if isSelected {
                    Image(icon: .check)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.onAction)
                        .frame(width: 28, height: 28)
                        .background(Palette.action, in: Circle())
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.row)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(isSelected ? Palette.surface : Palette.sunken, in: shape)
            .overlay { if isSelected { shape.strokeBorder(Palette.selectionInk, lineWidth: 1.5) } }
            .contentShape(shape)
        }
        .buttonStyle(ChoicePressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier ?? "")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
    }
}

private struct ChoicePressStyle: ButtonStyle {
    @Environment(\.motionPolicy) private var policy

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && policy.allowsMovement ? Motion.pressScaleRow : 1)
            .animation(policy.allowsMovement ? Motion.ease(Motion.Duration.press) : nil, value: configuration.isPressed)
            .sensoryFeedback(.selection, trigger: configuration.isPressed) { _, pressed in pressed }
    }
}
