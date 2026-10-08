//
//  OfflineBanner.swift
//  BelloHub
//

import SwiftUI

/// Shown at the top of a screen while the network is down. Offline is a normal state for the
/// professional's app, so it informs and never blocks.
struct OfflineBanner: View {
    let message: LocalizedStringKey
    @Environment(\.motionPolicy) private var policy

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(icon: .wifiSlash)
                .font(.system(size: 14, weight: .semibold))
                .accessibilityHidden(true)
            Text(message).font(Typography.footnoteStrong)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.amberText)
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: Spacing.touchTarget)
        .background(Palette.amberBg, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .transition(policy.allowsMovement
            ? .opacity.combined(with: .offset(y: -Motion.riseOffset))
            : .opacity)
        .accessibilityElement(children: .combine)
    }
}
