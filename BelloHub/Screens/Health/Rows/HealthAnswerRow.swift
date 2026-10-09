//
//  HealthAnswerRow.swift
//  BelloHub
//

import SwiftUI

/// One answer of the health form: the question on one side, the answer on the other. At accessibility sizes the two
/// stack, so a long choice never squeezes the question. One element for VoiceOver ("Allergies, Fragrance").
struct HealthAnswerRow: View {
    let name: String
    let value: String
    var isAnswered = true
    let identifier: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    label
                    answer
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    label
                    Spacer(minLength: Spacing.md)
                    answer.multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.row)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var label: some View {
        Text(verbatim: name).font(Typography.body).foregroundStyle(Palette.ink2)
    }

    private var answer: some View {
        Text(verbatim: value)
            .font(isAnswered ? Typography.bodyStrong : Typography.body)
            .foregroundStyle(isAnswered ? Palette.ink : Palette.ink2)
    }
}

#Preview {
    ListCard(dividerInset: Spacing.md) {
        HealthAnswerRow(name: "Allergies", value: "Fragrance", identifier: "preview.row1")
        HealthAnswerRow(name: "Medication", value: "Not answered", isAnswered: false, identifier: "preview.row2")
    }
    .padding()
    .background(Palette.bg)
}
