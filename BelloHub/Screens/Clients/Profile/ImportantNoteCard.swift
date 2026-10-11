//
//  ImportantNoteCard.swift
//  BelloHub
//

import SwiftUI

/// "Important to know": the private note and the allergies, at the top of the profile because they are what she must
/// not forget before the client sits down. On a rose wash, so its text is `roseDeepText` (`roseText` is 4.49:1 there).
struct ImportantNoteCard: View {
    let note: String?
    let allergies: [String]
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(icon: .alert)
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityHidden(true)
                Text("clientProfile.important.title")
                    .font(Typography.metaStrong)
                    .accessibilityAddTraits(.isHeader)
            }
            if !allergies.isEmpty {
                Text(LocalizedStringResource(
                    "clientProfile.important.allergies",
                    defaultValue: "Allergies: \(allergies.map(BidiIsolate.wrap).joined(separator: ", "))"
                ).localized(in: locale))
                    .font(Typography.subtitle)
            }
            if let note {
                Text(verbatim: note)
                    .font(Typography.body)
            }
        }
        .foregroundStyle(Palette.roseDeepText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Palette.roseWash, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("clientProfile.important")
    }
}

#Preview {
    ImportantNoteCard(note: "Sensitive skin, prefers fragrance-free products", allergies: ["Fragrance"])
        .padding()
}
