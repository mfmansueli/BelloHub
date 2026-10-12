//
//  TreatmentFlowViewModel+Options.swift
//  BelloHub
//

import Foundation

/// Quick answers and "+ Add" on the visit form: the answers her profession uses (from the catalog, or her template once
/// she added her own) one tap away on every written field, and a technique, a product, a reaction, an aftercare line or
/// a choice of one of her fields created without leaving the visit. "Use only this time" writes it into this record;
/// "Save to reuse" also keeps it in its own list (techniques, reactions and aftercare in her saved options, products in
/// her product list, a field's answers and choices in her template). The same name with other spaces or letter case is
/// the existing one, never a second (`OptionNameRules`).
extension TreatmentFlowViewModel {
    /// The quick answers a written field offers: her profession's (or her template's) first, then the ones she saved
    /// for this kind of answer (techniques, reactions, aftercare), each once.
    func quickTags(for field: TreatmentFormField) -> [String] {
        let saved = savedContext(for: field).map { options?.names(in: $0) ?? [] } ?? []
        return OptionNameRules.unique(field.tags + saved)
    }

    /// Her product list first, then the products and actives her profession uses most.
    func productSuggestions(for field: TreatmentFormField) -> [String] {
        OptionNameRules.unique(productNames + field.tags)
    }

    /// A quick answer tapped, or one she typed with "+ Add": written on its own line, after what is there. "Save to
    /// reuse" keeps it for next time: in her saved techniques, reactions or aftercare, or in the field's own answers
    /// in her template (starting from the profession's, so none of those is lost).
    func addTag(_ name: String, save: Bool, field: TreatmentFormField) {
        let current = draft.value(for: field.key)
        if OptionNameRules.match(name, in: TreatmentAnswerFormat.textLines(current)) == nil {
            set(current.isEmpty ? name : current + "\n" + name, for: field.key)
        }
        guard save else { return }
        if let context = savedContext(for: field) {
            guard let options else { return }
            Task { _ = try? await options.add(name, to: context) }
        } else {
            saveTagInTemplate(name, field: field)
        }
    }

    /// A quick answer tapped again: its line leaves the field; what she typed around it stays.
    func removeTag(_ name: String, field: TreatmentFormField) {
        let kept = draft.value(for: field.key).components(separatedBy: .newlines)
            .filter { OptionNameRules.match(name, in: [$0]) == nil }
        set(kept.joined(separator: "\n"), for: field.key)
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

    /// Where a saved answer of this field lives when it is not her template's: the fields every visit has, and the
    /// techniques, which she shares across professions.
    private func savedContext(for field: TreatmentFormField) -> OptionContext? {
        switch field.role {
        case .technique: .technique
        case .reaction: .reaction
        case .aftercare where field.key == TreatmentFormField.aftercareKey: .aftercare
        default: nil
        }
    }

    private func saveTagInTemplate(_ name: String, field: TreatmentFormField) {
        guard var template = profile.template,
              let index = template.fields.firstIndex(where: { $0.key == field.key }) else { return }
        let current = template.fields[index].options.isEmpty ? field.tags : template.fields[index].options
        guard OptionNameRules.match(name, in: current) == nil else { return }
        template.fields[index].options = current + [name]
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
