//
//  ToggleRow.swift
//  BelloHub
//

import SwiftUI

/// A row with a title, an optional line under it and the system switch. The switch is the native one, tinted sage,
/// so VoiceOver, Switch Control and Dynamic Type all behave as in Settings.
struct ToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    var identifier: String?

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: title)
                    .font(isOn ? Typography.bodyStrong : Typography.body)
                    .foregroundStyle(Palette.ink)
                if let subtitle {
                    Text(verbatim: subtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
        }
        .tint(Palette.sage)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 52)
        .accessibilityIdentifier(identifier ?? "")
    }
}
