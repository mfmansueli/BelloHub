//
//  ReviewMerge.swift
//  BelloHub
//

import Foundation

/// The rules of the review step (docs/12-AI-AND-VOICE.md section 4): what the technology proposed becomes cards, she
/// decides on every card, and only then does anything reach the form's draft. The gate is the same for the fake and
/// for a real service: no proposal is saved while one is pending, and `aiAssisted` is set only from a finished review.
enum ReviewMerge {
    /// The cards, plus how many proposed values were turned away because they cannot be a valid answer.
    struct Proposals: Equatable, Sendable {
        var items: [ReviewProposal]
        var rejectedCount: Int
    }

    /// One card per field the draft filled, in the form's order. A key that is not a field of her form, a blank
    /// value and a value that cannot be that field's answer (a choice she did not list, a number that is not one)
    /// make no card: the first two are ignored, the last is counted so the screen can say it left something out.
    static func proposals(
        from draft: StructuredRecordDraft, fields: [TreatmentFormField], locale: Locale
    ) -> Proposals {
        var items: [ReviewProposal] = []
        var rejected = 0
        for field in fields {
            guard let raw = draft.values[field.key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { continue }
            if let value = valid(raw, for: field, locale: locale) {
                items.append(ReviewProposal(field: field, proposed: value))
            } else {
                rejected += 1
            }
        }
        return Proposals(items: items, rejectedCount: rejected)
    }

    /// The fields the technology left empty: the review says they stay empty instead of guessed.
    static func notMentioned(_ items: [ReviewProposal], fields: [TreatmentFormField]) -> [TreatmentFormField] {
        let proposed = Set(items.map(\.field.key))
        return fields.filter { !proposed.contains($0.key) }
    }

    /// Every card has an answer from her.
    static func isComplete(_ items: [ReviewProposal]) -> Bool {
        !items.contains(where: \.isPending)
    }

    /// The draft with what she accepted or edited written in. Dropped and pending cards write nothing.
    static func apply(_ items: [ReviewProposal], to draft: TreatmentDraft) -> TreatmentDraft {
        var merged = draft
        for item in items {
            guard let value = item.finalValue else { continue }
            merged.set(value, for: item.field.key)
        }
        return merged
    }

    /// True only after a finished review in which at least one value that came from the proposal was kept. A review
    /// where she dropped everything saves a record the technology did not write.
    static func isAIAssisted(_ items: [ReviewProposal]) -> Bool {
        isComplete(items) && items.contains { $0.finalValue != nil }
    }

    // MARK: - Private

    /// The proposed text as a valid answer for the field, or nil.
    private static func valid(_ text: String, for field: TreatmentFormField, locale: Locale) -> String? {
        switch field.input {
        case .text, .products:
            return text
        case .number:
            if case .value = PriceInput(text, locale: locale) { return text }
            return nil
        case .choice(let options):
            return options.first { $0.caseInsensitiveCompare(text) == .orderedSame }
        case .multiChoice(let options):
            let picked = text.components(separatedBy: RecordFieldEntry.optionSeparator).compactMap { part in
                options.first { $0.caseInsensitiveCompare(part.trimmingCharacters(in: .whitespaces)) == .orderedSame }
            }
            return picked.isEmpty ? nil : picked.joined(separator: RecordFieldEntry.optionSeparator)
        case .yesNo:
            switch text.lowercased() {
            case RecordFieldEntry.yes: return RecordFieldEntry.yes
            case RecordFieldEntry.no: return RecordFieldEntry.no
            default: return nil
            }
        }
    }
}
