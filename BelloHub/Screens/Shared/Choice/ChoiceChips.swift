//
//  ChoiceChips.swift
//  BelloHub
//

import SwiftUI

/// A titled row of choice chips that wraps onto more lines as needed: one is selected, and tapping it again may clear
/// it. Used by the forms that pick one of a few short options (category, price visibility, follow-up, product kind).
/// It is a row of buttons and not a `Picker` because the options are few and short, all visible at once, as in the
/// prototype; each chip carries the selected trait and its own identifier. `trailing` adds a chip of the caller's
/// own ("+ New").
struct ChoiceChips<Option: Hashable, Trailing: View>: View {
    let title: LocalizedStringKey
    let options: [Option]
    let isSelected: (Option) -> Bool
    let label: (Option) -> String
    /// The accessibility identifier of one chip, such as `serviceEditor.category.Facial`.
    let identifier: (Option) -> String
    let onSelect: (Option) -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title).font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                ForEach(options, id: \.self) { option in
                    Button { onSelect(option) } label: { Text(verbatim: label(option)) }
                        .buttonStyle(.belloChip(selected: isSelected(option)))
                        .accessibilityAddTraits(isSelected(option) ? .isSelected : [])
                        .accessibilityIdentifier(identifier(option))
                }
                trailing
            }
        }
    }
}

extension ChoiceChips where Trailing == EmptyView {
    init(
        title: LocalizedStringKey, options: [Option], isSelected: @escaping (Option) -> Bool,
        label: @escaping (Option) -> String, identifier: @escaping (Option) -> String,
        onSelect: @escaping (Option) -> Void
    ) {
        self.init(
            title: title, options: options, isSelected: isSelected, label: label, identifier: identifier,
            onSelect: onSelect, trailing: { EmptyView() }
        )
    }
}

#Preview {
    ChoiceChips(
        title: "onb.service.duration", options: [30, 45, 60], isSelected: { $0 == 45 }, label: { "\($0)" },
        identifier: { "preview.\($0)" }, onSelect: { _ in }
    )
    .padding()
}
