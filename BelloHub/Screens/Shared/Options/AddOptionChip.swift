//
//  AddOptionChip.swift
//  BelloHub
//

import SwiftUI

/// The "+ Add" chip at the end of a row of options.
struct AddOptionChip: View {
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label { Text("optionAdd.chip") } icon: { Image(icon: .plus) }
        }
        .buttonStyle(.belloChip(selected: false))
        .accessibilityIdentifier(identifier)
    }
}
