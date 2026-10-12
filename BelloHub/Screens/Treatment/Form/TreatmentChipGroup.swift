//
//  TreatmentChipGroup.swift
//  BelloHub
//

import SwiftUI

/// A titled row of choice chips for a field she answers by picking: one option (tap again to clear) or several. The
/// title and the options are text she wrote (her own field), so they are shown as they are. Each chip carries the
/// selected trait and its own identifier.
struct TreatmentChipGroup: View {
    let title: String
    let options: [String]
    let isSelected: (String) -> Bool
    let label: (String) -> String
    let identifier: (String) -> String
    let onTap: (String) -> Void
    /// "+ Add" at the end of the chips; nil hides it.
    var onAdd: (() -> Void)?
    var addIdentifier = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(verbatim: title).font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                ForEach(options, id: \.self) { option in
                    Button { onTap(option) } label: { Text(verbatim: label(option)) }
                        .buttonStyle(.belloChip(selected: isSelected(option)))
                        .accessibilityAddTraits(isSelected(option) ? .isSelected : [])
                        .accessibilityIdentifier(identifier(option))
                }
                if let onAdd { AddOptionChip(identifier: addIdentifier, action: onAdd) }
            }
        }
    }
}

#Preview {
    TreatmentChipGroup(
        title: "Areas", options: ["Cheeks", "Forehead", "Chin"], isSelected: { $0 == "Cheeks" }, label: { $0 },
        identifier: { "preview.\($0)" }, onTap: { _ in }
    )
    .padding()
}
