//
//  HealthQuestionView.swift
//  BelloHub
//

import SwiftUI

/// One question of the health form sheet, with the control its kind needs: yes or no chips, choice chips (with an
/// exclusive "None"), or a free-text note. The question is read first, then its answers, as one group for VoiceOver.
struct HealthQuestionView: View {
    let viewModel: HealthFormViewModel
    let question: HealthQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            Text(verbatim: question.prompt)
                .font(Typography.bodyStrong)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            control
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var control: some View {
        switch question.kind {
        case .yesNo:
            YesNoChips(
                isYes: viewModel.answer(for: question).map { $0 == .yes },
                identifier: "healthForm.question.\(question.key)"
            ) { viewModel.setYesNo($0, for: question) }
        case .choices:
            choices
        case .text:
            BelloNoteField(
                title: Text(verbatim: question.prompt),
                text: Binding(
                    get: { viewModel.text(for: question) }, set: { viewModel.setText($0, for: question) }
                ),
                prompt: "healthForm.optional", showsTitle: false, isSensitive: true,
                identifier: "healthForm.question.\(question.key).field"
            )
        }
    }

    private var choices: some View {
        // Some choices are long ("Injectables (filler or botulinum toxin)"): a chip wraps instead of overflowing.
        FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
            ForEach(question.options) { option in
                chip(isOn: viewModel.isChoiceOn(option.key, for: question), key: option.key) {
                    Text(verbatim: option.name)
                }
            }
            if question.allowsNone {
                chip(isOn: viewModel.isChoiceOn(HealthOption.noneKey, for: question), key: HealthOption.noneKey) {
                    Text("health.answer.none")
                }
            }
        }
    }

    private func chip(isOn: Bool, key: String, @ViewBuilder label: () -> some View) -> some View {
        Button { viewModel.toggleChoice(key, for: question) } label: { label() }
            .buttonStyle(.belloChip(selected: isOn))
            .accessibilityAddTraits(isOn ? .isSelected : [])
            .accessibilityIdentifier("healthForm.question.\(question.key).option.\(key)")
    }
}
