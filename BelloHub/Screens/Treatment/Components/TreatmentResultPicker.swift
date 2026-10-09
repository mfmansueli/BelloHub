//
//  TreatmentResultPicker.swift
//  BelloHub
//

import SwiftUI

/// "How did it go?": one of four chips, optional (tap the chosen one again to clear it). The words describe the visit,
/// never the client.
struct TreatmentResultPicker: View {
    @Binding var result: RecordResult?
    var idPrefix = "treatmentFlow.form"

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("treatmentFlow.result.title").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                ForEach(RecordResult.allCases, id: \.self) { option in
                    Button { result = result == option ? nil : option } label: {
                        Text(option.title.localized(in: locale))
                    }
                    .buttonStyle(.belloChip(selected: result == option))
                    .accessibilityAddTraits(result == option ? .isSelected : [])
                    .accessibilityIdentifier("\(idPrefix).result.\(option.rawValue)")
                }
            }
        }
    }
}

#Preview {
    TreatmentResultPicker(result: .constant(.good)).padding()
}
