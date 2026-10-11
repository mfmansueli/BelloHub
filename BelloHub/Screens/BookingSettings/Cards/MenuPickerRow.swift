//
//  MenuPickerRow.swift
//  BelloHub
//

import SwiftUI

/// A row with a title and the native menu picker at its end ("Buffer between clients: 15 min"). The system menu is
/// kept, so VoiceOver, Switch Control and Dynamic Type work as in Settings; the row only gives it the card's look. An
/// optional `hint` under the row explains the setting with an example from her routine.
struct MenuPickerRow: View {
    let title: LocalizedStringKey
    @Binding var selection: Int
    let options: [Int]
    let label: (Int) -> String
    let identifier: String
    var hint: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.row) {
                Text(title).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Picker(selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(verbatim: label(option)).tag(option)
                    }
                } label: {
                    Text(title)
                }
                .pickerStyle(.menu)
                .tint(Palette.roseText)
                .accessibilityIdentifier(identifier)
            }
            .frame(minHeight: 56)
            if let hint {
                Text(hint).font(Typography.footnote).foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Spacing.sm)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }
}
