//
//  ServiceCategorySection.swift
//  BelloHub
//

import SwiftUI

/// The category of the service: the ones she already uses as chips, and "+ New" for one of her own. The category is
/// optional, so tapping the chosen one again clears it. While she is naming a new one, a text field takes the place of
/// the "+ New" chip's promise and the chips show nothing chosen.
struct ServiceCategorySection: View {
    @Binding var draft: ServiceDraft
    /// The chips, fixed when the form opened: a category she is still typing never becomes a chip of its own.
    let categories: [String]

    @State private var isNaming: Bool
    @FocusState private var isFocused: Bool

    init(draft: Binding<ServiceDraft>, categories: [String]) {
        _draft = draft
        self.categories = categories
        // With no category to pick from there is nothing but the field to show.
        _isNaming = State(initialValue: categories.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ChoiceChips(
                title: "onb.service.category",
                options: categories,
                isSelected: { OnboardingRules.comparisonKey($0) == OnboardingRules.comparisonKey(draft.category) },
                label: { $0 },
                identifier: { "serviceEditor.category.\($0)" },
                onSelect: select,
                trailing: { newChip }
            )
            if isNaming {
                BelloTextField(
                    title: "services.category.name", text: $draft.category, prompt: "onb.service.category",
                    identifier: "serviceEditor.categoryField"
                )
                .focused($isFocused)
            }
        }
    }

    @ViewBuilder
    private var newChip: some View {
        if !categories.isEmpty {
            Button { startNaming() } label: { Text("services.category.new") }
                .buttonStyle(.belloChip(selected: isNaming))
                .accessibilityAddTraits(isNaming ? .isSelected : [])
                .accessibilityIdentifier("serviceEditor.category.new")
        }
    }

    private func select(_ category: String) {
        isNaming = false
        let isChosen = OnboardingRules.comparisonKey(category) == OnboardingRules.comparisonKey(draft.category)
        draft.category = isChosen ? "" : category
    }

    private func startNaming() {
        isNaming = true
        draft.category = ""
        isFocused = true
    }
}
