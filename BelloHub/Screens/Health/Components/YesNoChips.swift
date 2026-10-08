//
//  YesNoChips.swift
//  BelloHub
//

import SwiftUI

/// "Yes" and "No" as two chips. Neither is selected until she picks one: an unanswered question and a "no" are
/// different things on a health form. Each chip says whether it is selected to VoiceOver.
struct YesNoChips: View {
    /// Nil until answered.
    let isYes: Bool?
    /// The identifiers become `<identifier>.yes` and `<identifier>.no`.
    let identifier: String
    let onSelect: (Bool) -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            chip("health.answer.yes", isSelected: isYes == true, suffix: "yes") { onSelect(true) }
            chip("health.answer.no", isSelected: isYes == false, suffix: "no") { onSelect(false) }
            Spacer(minLength: 0)
        }
    }

    private func chip(
        _ title: LocalizedStringKey, isSelected: Bool, suffix: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { Text(title) }
            .buttonStyle(.belloChip(selected: isSelected))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("\(identifier).\(suffix)")
    }
}

#Preview {
    VStack(alignment: .leading) {
        YesNoChips(isYes: nil, identifier: "preview.a", onSelect: { _ in })
        YesNoChips(isYes: true, identifier: "preview.b", onSelect: { _ in })
    }
    .padding()
    .background(Palette.bg)
}
