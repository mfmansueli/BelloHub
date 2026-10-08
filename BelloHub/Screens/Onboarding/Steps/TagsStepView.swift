//
//  TagsStepView.swift
//  BelloHub
//

import SwiftUI

/// 1.7 Onb-6-Tags. Private labels she puts on clients. Pick a few suggested ones and add her own; "+ New tag" opens
/// a small prompt.
struct TagsStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showsNewTag = false
    @State private var newTagName = ""

    var body: some View {
        OnboardingStepLayout(
            title: Text("onb.tags.title"), subtitle: Text("onb.tags.subtitle"), canContinue: viewModel.canContinue,
            identifier: "tags", onContinue: viewModel.goNext
        ) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                FlowLayout {
                    ForEach(viewModel.suggestedTags) { tag in
                        Button { viewModel.toggleTag(tag.key) } label: { Text(verbatim: tag.name) }
                            .buttonStyle(.belloChip(selected: viewModel.isTagSelected(tag.key)))
                            .accessibilityAddTraits(viewModel.isTagSelected(tag.key) ? .isSelected : [])
                            .accessibilityIdentifier("onboarding.tags.choice.\(tag.key)")
                    }
                    ForEach(viewModel.draft.customTags, id: \.self) { name in
                        Button { viewModel.removeCustomTag(name) } label: { Text(verbatim: name) }
                            .buttonStyle(.belloChip(selected: true))
                            .accessibilityAddTraits(.isSelected)
                            .accessibilityHint(Text("onb.tags.removeHint"))
                    }
                    Button { showsNewTag = true } label: { Text("onb.tags.new") }
                        .buttonStyle(.belloChip(selected: false))
                        .foregroundStyle(Palette.roseText)
                        .accessibilityIdentifier("onboarding.tags.newButton")
                }
                FooterNote(text: "onb.tags.footer", icon: .lock)
            }
        }
        .alert(Text("onb.tags.newTitle"), isPresented: $showsNewTag) {
            TextField(text: $newTagName) { Text("onb.tags.namePrompt") }
            Button { commitNewTag() } label: { Text("onb.tags.add") }
            Button(role: .cancel) { newTagName = "" } label: { Text("common.cancel") }
        }
    }

    private func commitNewTag() {
        _ = viewModel.addCustomTag(newTagName)
        newTagName = ""
    }
}
