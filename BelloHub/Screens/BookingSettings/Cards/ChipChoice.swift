//
//  ChipChoice.swift
//  BelloHub
//

import SwiftUI

/// A row of chips where exactly one is chosen ("2 h, 12 h, 24 h…"). The chips wrap onto more lines when the text is
/// large or long, and each is a button with the selected trait, so VoiceOver reads "selected". Generic over what it
/// picks.
struct ChipChoice<Value: Hashable>: View {
    let options: [Value]
    let selection: Value
    let label: (Value) -> String
    /// The accessibility identifier of one chip, such as `cancelPolicy.window.24`.
    let identifier: (Value) -> String
    let onSelect: (Value) -> Void

    var body: some View {
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button { onSelect(option) } label: { Text(verbatim: label(option)) }
                    .buttonStyle(.belloChip(selected: isSelected))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier(identifier(option))
            }
        }
    }
}
