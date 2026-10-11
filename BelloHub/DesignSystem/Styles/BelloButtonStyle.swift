//
//  BelloButtonStyle.swift
//  BelloHub
//

import SwiftUI

/// The one button style (docs/08-DESIGN-SYSTEM.md section 6). Screens pick a variant through the static
/// helpers (`.belloPrimary`, `.belloSecondary`, ...) and never build a style by hand. One primary
/// action per screen. Pressing scales to 0.97 and gives a light haptic; both respect Reduce Motion
/// (the system turns haptics off by itself when the user asks).
struct BelloButtonStyle: ButtonStyle {
    enum Variant: Equatable {
        case primary
        case secondary
        case tertiary
        case onHero
        case destructive
        /// Filter chip. `selected` gives it the selection fill, label and ring.
        case chip(selected: Bool)
    }

    var variant: Variant = .primary
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.motionPolicy) private var policy

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        return configuration.label
            .font(font)
            .foregroundStyle(foreground)
            .multilineTextAlignment(.center)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: isChip ? nil : .infinity, minHeight: height)
            .background(background, in: shape)
            .overlay { border }
            .shadow(color: shadowColor, radius: 10, x: 0, y: 10)
            .contentShape(shape)
            .scaleEffect(isPressed && policy.allowsMovement ? Motion.pressScale : 1)
            .opacity(isPressed && policy.allowsFade ? 0.97 : 1)
            .animation(policy.allowsMovement ? Motion.ease(Motion.Duration.press) : nil, value: isPressed)
            .opacity(isEnabled ? 1 : 0.4)
            .sensoryFeedback(feedback, trigger: isPressed) { _, pressed in pressed }
    }

    // MARK: - Metrics

    private var isChip: Bool {
        if case .chip = variant { return true }
        return false
    }

    private var height: CGFloat {
        isChip ? Spacing.touchTarget : 56
    }

    private var horizontalPadding: CGFloat {
        isChip ? Spacing.md : Spacing.lg
    }

    private var shape: AnyShape {
        isChip ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
    }

    private var font: Font {
        switch variant {
        case .tertiary: Typography.calloutStrong
        case .chip: Typography.metaStrong
        default: Typography.bodyStrong
        }
    }

    private var feedback: SensoryFeedback {
        switch variant {
        case .chip: .selection
        case .destructive: .warning
        default: .impact(weight: .light)
        }
    }

    // MARK: - Colors

    private var foreground: Color {
        switch variant {
        case .primary: Palette.onAction
        case .secondary: Palette.ink
        case .tertiary: Palette.roseText
        case .onHero: HeroPalette.ink
        case .destructive: Palette.coralText
        case .chip(let selected): selected ? Palette.selectionInk : Palette.ink
        }
    }

    private var background: Color {
        switch variant {
        case .primary: Palette.action
        case .secondary: Palette.surface
        case .tertiary: .clear
        case .onHero: HeroPalette.raised
        case .destructive: Palette.coralBg
        case .chip(let selected): selected ? Palette.selectionFill : Palette.surface
        }
    }

    @ViewBuilder
    private var border: some View {
        switch variant {
        case .secondary:
            RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                .strokeBorder(Palette.fieldBorder, lineWidth: 1)
        case .chip(selected: false):
            Capsule().strokeBorder(Palette.fieldBorder, lineWidth: 1)
        case .chip(selected: true):
            // Why a ring: the selection fill is only 1.4:1 against the page in light, so the 1.5 pt ring in the label
            // color is what makes the selected state perceivable (WCAG 1.4.11).
            Capsule().strokeBorder(Palette.selectionInk, lineWidth: 1.5)
        default:
            EmptyView()
        }
    }

    private var shadowColor: Color {
        // A soft lift in the neutral shadow tint; the old graphite at 50 % was heavy under a sage fill.
        variant == .primary && isEnabled ? Elevation.tint.opacity(0.22) : .clear
    }
}

extension ButtonStyle where Self == BelloButtonStyle {
    static var belloPrimary: BelloButtonStyle { BelloButtonStyle(variant: .primary) }
    static var belloSecondary: BelloButtonStyle { BelloButtonStyle(variant: .secondary) }
    static var belloTertiary: BelloButtonStyle { BelloButtonStyle(variant: .tertiary) }
    static var belloOnHero: BelloButtonStyle { BelloButtonStyle(variant: .onHero) }
    static var belloDestructive: BelloButtonStyle { BelloButtonStyle(variant: .destructive) }
    static func belloChip(selected: Bool) -> BelloButtonStyle { BelloButtonStyle(variant: .chip(selected: selected)) }
}
