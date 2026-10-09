//
//  MenuPickerRow.swift
//  BelloHub
//

import SwiftUI

/// A row with a title and the native menu picker at its end ("Buffer between clients: 15 min"). The system menu is
/// kept, so VoiceOver, Switch Control and Dynamic Type work as in Settings; the row only gives it the card's look.
struct MenuPickerRow: View {
    let title: LocalizedStringKey
    @Binding var selection: Int
    let options: [Int]
    let label: (Int) -> String
    let identifier: String

    var body: some View {
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
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 56)
    }
}
