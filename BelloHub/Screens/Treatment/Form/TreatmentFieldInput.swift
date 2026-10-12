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
    /// The choices a choice field shows, when the caller adds ones used only on this record; nil for the template's.
    var choices: [String]?
    /// Quick answers offered under a written field (her profession's, her template's and the ones she saved), one tap
    /// away.
    var textSuggestions: [String] = []
    /// "+ Add": the name and whether to save it for reuse. Nil hides the chip (the review cards).
    var onAddOption: ((String, Bool) -> Void)?
    /// A saved word tapped again on a text field: takes its line out.
    var onRemoveOption: ((String) -> Void)?

    @Environment(\.locale) private var locale
    @State private var isAdding = false

    private var identifier: String { "\(idPrefix).field.\(field.key)" }

    var body: some View {
        content
            .sheet(isPresented: $isAdding) {
                OptionAddSheet(
                    title: Text(LocalizedStringResource("optionAdd.title", defaultValue: "Add to \(field.name)")
                        .localized(in: locale)),
                    existing: existingOptions
                ) { name, save in onAddOption?(name, save) }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch field.input {
        case .text: textInput
        case .number(let unit): numberInput(unit: unit)
        case .choice(let options): choiceInput(choices ?? options)
        case .multiChoice(let options): multiChoiceInput(choices ?? options)
        case .yesNo: yesNoInput
        case .products:
            TreatmentProductsInput(
                title: field.name, value: $value, suggestions: suggestions, idPrefix: identifier,
                onAdd: onAddOption == nil ? nil : { isAdding = true }
            )
        }
    }

    /// What "+ Add" suggests as she types: the options this field already offers.
    private var existingOptions: [String] {
        switch field.input {
        case .products: suggestions
        case .choice(let options), .multiChoice(let options): choices ?? options
        default: textSuggestions
        }
    }

    /// The field's quick answers, and "+ Add". One answer per line: a chip is on while its line is in the field.
    @ViewBuilder
    private var optionRow: some View {
        if onAddOption != nil {
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                ForEach(textSuggestions, id: \.self) { word in
                    let isOn = OptionNameRules.match(word, in: TreatmentAnswerFormat.textLines(value)) != nil
                    Button { isOn ? onRemoveOption?(word) : onAddOption?(word, false) } label: { Text(verbatim: word) }
                        .buttonStyle(.belloChip(selected: isOn))
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                        .accessibilityIdentifier("\(identifier).option.\(word)")
                }
                AddOptionChip(identifier: "\(identifier).addOption") { isAdding = true }
            }
        }
    }

    // MARK: - Inputs

    /// A field with quick answers is a note with its chips under it, so a tap or a few words both fit; a field she
    /// made for a word or two, with no answers yet, is one line.
    @ViewBuilder
    private var textInput: some View {
        if field.role == .generic, textSuggestions.isEmpty {
            BelloTextField(
                titleText: Text(verbatim: field.name), text: $value, isSensitive: true, identifier: identifier
            )
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                BelloNoteField(title: Text(verbatim: field.name), text: $value, isSensitive: true,
                               identifier: identifier)
                optionRow
            }
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
            identifier: { "\(identifier).\($0)" }, onTap: { value = value == $0 ? "" : $0 },
            onAdd: onAddOption == nil ? nil : { isAdding = true }, addIdentifier: "\(identifier).addOption"
        )
    }

    private func multiChoiceInput(_ options: [String]) -> some View {
        let picked = TreatmentAnswerFormat.items(value)
        return TreatmentChipGroup(
            title: field.name, options: options, isSelected: { picked.contains($0) }, label: { $0 },
            identifier: { "\(identifier).\($0)" },
            onTap: { value = TreatmentAnswerFormat.join(TreatmentAnswerFormat.toggled($0, in: picked)) },
            onAdd: onAddOption == nil ? nil : { isAdding = true }, addIdentifier: "\(identifier).addOption"
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

    private var yesText: String {
        LocalizedStringResource("health.answer.yes", defaultValue: "Yes").resolved(in: locale)
    }

    private var noText: String { LocalizedStringResource("health.answer.no", defaultValue: "No").resolved(in: locale) }
}
