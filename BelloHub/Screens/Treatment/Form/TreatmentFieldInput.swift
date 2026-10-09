//
//  TreatmentFieldInput.swift
//  BelloHub
//

import SwiftUI

/// The control for one question of the form, chosen by how the field is answered: a note for free text, a number with
/// its unit, chips to pick one or several options, yes or no, or the products list. Used by the manual form and by the
/// review's edit, so a value is always edited the same way. The answer is the stored string (`TreatmentDraft`).
struct TreatmentFieldInput: View {
    let field: TreatmentFormField
    @Binding var value: String
    var suggestions: [String] = []
    var hasError = false
    var idPrefix = "treatmentFlow.form"

    @Environment(\.locale) private var locale

    private var identifier: String { "\(idPrefix).field.\(field.key)" }

    var body: some View {
        switch field.input {
        case .text: textInput
        case .number(let unit): numberInput(unit: unit)
        case .choice(let options): choiceInput(options)
        case .multiChoice(let options): multiChoiceInput(options)
        case .yesNo: yesNoInput
        case .products:
            TreatmentProductsInput(title: field.name, value: $value, suggestions: suggestions, idPrefix: identifier)
        }
    }

    // MARK: - Inputs

    /// Observations, technique, result and aftercare are sentences; a field she made for a word or two is one line.
    @ViewBuilder
    private var textInput: some View {
        if field.role == .generic {
            BelloTextField(titleText: Text(verbatim: field.name), text: $value, isSensitive: true, identifier: identifier)
        } else {
            BelloNoteField(title: Text(verbatim: field.name), text: $value, isSensitive: true, identifier: identifier)
        }
    }

    private func numberInput(unit: String?) -> some View {
        let name = unit.map { "\(field.name) (\($0))" } ?? field.name
        return BelloTextField(
            titleText: Text(verbatim: name), text: $value,
            errorMessage: hasError ? "treatmentFlow.form.error.number" : nil, identifier: identifier
        )
        .keyboardType(.decimalPad)
    }

    private func choiceInput(_ options: [String]) -> some View {
        TreatmentChipGroup(
            title: field.name, options: options, isSelected: { $0 == value }, label: { $0 },
            identifier: { "\(identifier).\($0)" }, onTap: { value = value == $0 ? "" : $0 }
        )
    }

    private func multiChoiceInput(_ options: [String]) -> some View {
        let picked = TreatmentAnswerFormat.items(value)
        return TreatmentChipGroup(
            title: field.name, options: options, isSelected: { picked.contains($0) }, label: { $0 },
            identifier: { "\(identifier).\($0)" },
            onTap: { value = TreatmentAnswerFormat.join(TreatmentAnswerFormat.toggled($0, in: picked)) }
        )
    }

    private var yesNoInput: some View {
        TreatmentChipGroup(
            title: field.name, options: [RecordFieldEntry.yes, RecordFieldEntry.no],
            isSelected: { $0 == value },
            label: { $0 == RecordFieldEntry.yes ? yesText : noText },
            identifier: { "\(identifier).\($0)" }, onTap: { value = value == $0 ? "" : $0 }
        )
    }

    private var yesText: String { LocalizedStringResource("health.answer.yes", defaultValue: "Yes").resolved(in: locale) }

    private var noText: String { LocalizedStringResource("health.answer.no", defaultValue: "No").resolved(in: locale) }
}
