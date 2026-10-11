//
//  ClientFilterChips.swift
//  BelloHub
//

import SwiftUI

/// The chips above the client list: everyone, the three questions she asks most, and one chip per tag. A horizontal
/// scroll, so a long tag list or the largest text size never clips a chip.
struct ClientFilterChips: View {
    let chips: [ClientListFilter]
    let selected: ClientListFilter
    let tagsByID: [UUID: Tag]
    let onSelect: (ClientListFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(chips, id: \.self) { chip in
                    Button { onSelect(chip) } label: { label(for: chip) }
                        .buttonStyle(.belloChip(selected: chip == selected))
                        .accessibilityAddTraits(chip == selected ? .isSelected : [])
                        .accessibilityIdentifier("clients.filter.\(chip.identifier)")
                }
            }
            .padding(.horizontal, Spacing.gutter)
        }
    }

    @ViewBuilder
    private func label(for chip: ClientListFilter) -> some View {
        switch chip {
        case .all: Text("clients.filter.all")
        case .dueToReturn: Text("clients.filter.dueToReturn")
        case .cancelsOften: Text("clients.filter.cancelsOften")
        case .new: Text("clients.filter.new")
        case .archived: Text("clients.filter.archived")
        case .tag(let id): Text(verbatim: tagsByID[id]?.name ?? "")
        }
    }
}

#Preview {
    ClientFilterChips(
        chips: [.all, .dueToReturn, .cancelsOften, .new, .archived], selected: .all, tagsByID: [:], onSelect: { _ in }
    )
}
