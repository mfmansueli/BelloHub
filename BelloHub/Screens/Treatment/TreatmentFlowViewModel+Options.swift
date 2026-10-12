//
//  TreatmentFlowViewModel+Options.swift
//  BelloHub
//

import Foundation

/// "+ Add" on the visit form: a technique, a product or a choice of one of her fields, created without leaving the
/// visit and used at once. "Use only this time" writes it into this record; "Save to reuse" also keeps it in its own
/// list (techniques in her saved options, products in her product list, a field's choice in her template). The same
/// name with other spaces or letter case is the existing one, never a second (`OptionNameRules`).
extension TreatmentFlowViewModel {
    /// Her saved techniques, offered over the technique field.
    var techniqueSuggestions: [String] {
        options?.names(in: .technique) ?? []
    }

    /// Adds a technique to the technique field (on a new line when there is text already).
    func addTechnique(_ name: String, save: Bool, fieldKey: String) {
        let current = draft.value(for: fieldKey)
        if OptionNameRules.match(name, in: TreatmentAnswerFormat.textLines(current)) == nil {
            set(current.isEmpty ? name : current + "\n" + name, for: fieldKey)
        }
        guard save, let options else { return }
        Task { _ = try? await options.add(name, to: .technique) }
    }

    /// A saved technique chip tapped again: its line leaves the field; what she typed around it stays.
    func removeTechnique(_ name: String, fieldKey: String) {
        let kept = draft.value(for: fieldKey).components(separatedBy: .newlines)
            .filter { OptionNameRules.match(name, in: [$0]) == nil }
        set(kept.joined(separator: "\n"), for: fieldKey)
    }

    /// Adds a product to the products field, and to her product list when she saves it.
    func addProduct(_ name: String, save: Bool, fieldKey: String) {
        set(TreatmentAnswerFormat.join(TreatmentAnswerFormat.adding(name, to: draft.lines(for: fieldKey))),
            for: fieldKey)
        guard save, OptionNameRules.match(name, in: productNames) == nil, let repository else { return }
        productNames.append(name)
        Task {
            let existing = (try? await repository.products()) ?? []
            try? await repository.save(Product(name: name, position: PositionRules.next(after: existing)))
        }
    }

    /// Picks a choice she typed for one of her fields; saving adds it to the field's options in her template.
    func addChoice(_ name: String, save: Bool, field: TreatmentFormField) {
        switch field.input {
        case .multiChoice:
            let picked = TreatmentAnswerFormat.items(draft.value(for: field.key))
            set(TreatmentAnswerFormat.join(TreatmentAnswerFormat.adding(name, to: picked)), for: field.key)
        default:
            set(name, for: field.key)
        }
        guard save, var template = profile.template,
              let index = template.fields.firstIndex(where: { $0.key == field.key }),
              OptionNameRules.match(name, in: template.fields[index].options) == nil else { return }
        template.fields[index].options.append(name)
        template.updatedAt = now()
        Task {
            try? await profile.saveTemplate(template)
            buildFieldsKeepingAnswers()
        }
    }

    /// The choices a field offers: her template's, plus a value written on this record that is not among them (one
    /// she used only this time), so the chip shows as chosen.
    func choices(for field: TreatmentFormField) -> [String] {
        let base: [String] = switch field.input {
        case .choice(let options), .multiChoice(let options): options
        default: []
        }
        let used = TreatmentAnswerFormat.items(draft.value(for: field.key))
        return base + used.filter { OptionNameRules.match($0, in: base) == nil }
    }
}
