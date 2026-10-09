//
//  ReviewCard.swift
//  BelloHub
//

import SwiftUI

/// One proposed field in the review: its name, the proposed answer and what she decides. Keep saves it as proposed,
/// Edit lets her change it with the same control as the form, Drop leaves the field empty. Until she decides, the card
/// says it is waiting and nothing from it is saved. The decision is spoken and written, never only a color.
struct ReviewCard: View {
    let proposal: ReviewProposal
    let suggestions: [String]
    let onKeep: () -> Void
    let onEdit: (String) -> Void
    let onDrop: () -> Void
    let onReopen: () -> Void

    @Environment(\.locale) private var locale
    @State private var isEditing = false
    @State private var editedValue = ""

    private var identifier: String { "treatmentFlow.review.card.\(proposal.field.key)" }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: proposal.field.name).font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                Spacer(minLength: Spacing.sm)
                statusLabel
            }
            if isEditing { editor } else { valueAndActions }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Parts

    private var valueAndActions: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(verbatim: shownText).font(Typography.body)
                .foregroundStyle(proposal.decision == .dropped ? Palette.ink2 : Palette.ink)
                .strikethrough(proposal.decision == .dropped)
                .accessibilityIdentifier("\(identifier).value")
            if proposal.isPending {
                FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                    Button(action: onKeep) { Text("treatmentFlow.review.keep") }
                        .buttonStyle(.belloChip(selected: true))
                        .accessibilityIdentifier("\(identifier).keep")
                    Button(action: startEditing) { Text("treatmentFlow.review.edit") }
                        .buttonStyle(.belloChip(selected: false))
                        .accessibilityIdentifier("\(identifier).edit")
                    Button(action: onDrop) { Text("treatmentFlow.review.drop") }
                        .buttonStyle(.belloChip(selected: false))
                        .accessibilityIdentifier("\(identifier).drop")
                }
            } else {
                Button(action: onReopen) { Text("treatmentFlow.review.change") }
                    .buttonStyle(.belloTertiary)
                    .frame(minHeight: Spacing.touchTarget)
                    .accessibilityIdentifier("\(identifier).change")
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TreatmentFieldInput(
                field: proposal.field, value: $editedValue, suggestions: suggestions,
                idPrefix: "treatmentFlow.review"
            )
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                Button {
                    onEdit(editedValue)
                    isEditing = false
                } label: { Text("treatmentFlow.review.saveEdit") }
                    .buttonStyle(.belloChip(selected: true))
                    .accessibilityIdentifier("\(identifier).saveEdit")
                Button { isEditing = false } label: { Text("common.cancel") }
                    .buttonStyle(.belloChip(selected: false))
                    .accessibilityIdentifier("\(identifier).cancelEdit")
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch proposal.decision {
        case .pending:
            Text("treatmentFlow.review.status.pending").font(Typography.footnoteStrong).foregroundStyle(Palette.amberText)
        case .accepted:
            Text("treatmentFlow.review.status.kept").font(Typography.footnoteStrong).foregroundStyle(Palette.sageText)
        case .edited:
            Text("treatmentFlow.review.status.edited").font(Typography.footnoteStrong).foregroundStyle(Palette.sageText)
        case .dropped:
            Text("treatmentFlow.review.status.dropped").font(Typography.footnoteStrong).foregroundStyle(Palette.ink2)
        }
    }

    private var shownText: String {
        TreatmentAnswerFormat.display(
            proposal.shownValue, input: proposal.field.input, yes: word("health.answer.yes", "Yes"),
            no: word("health.answer.no", "No"), locale: locale
        )
    }

    private func word(_ key: StaticString, _ fallback: String.LocalizationValue) -> String {
        LocalizedStringResource(key, defaultValue: fallback).resolved(in: locale)
    }

    private func startEditing() {
        editedValue = proposal.shownValue
        isEditing = true
    }
}
