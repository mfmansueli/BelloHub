//
//  VisitFormSections.swift
//  BelloHub
//

import Foundation

/// How the visit form lays out its fields: the quick note on top, her profession's fields (a few at once, the rest
/// folded), then the result and the reaction, then the aftercare and what to remember. Each field appears in exactly
/// one place. Pure, so the layout is tested without a screen.
struct VisitFormSections: Equatable, Sendable {
    let quickNote: TreatmentFormField?
    let profession: [TreatmentFormField]
    let moreProfession: [TreatmentFormField]
    let result: [TreatmentFormField]
    let guidance: [TreatmentFormField]

    static func split(_ fields: [TreatmentFormField], draft: TreatmentDraft) -> VisitFormSections {
        var quickNote: TreatmentFormField?
        var profession: [TreatmentFormField] = []
        var result: [TreatmentFormField] = []
        var guidance: [TreatmentFormField] = []
        for field in fields {
            switch field.role {
            case .notes: quickNote = field
            case .result, .reaction: result.append(field)
            case .aftercare, .nextVisitReminder: guidance.append(field)
            case .nextSession: continue
            case .products, .technique, .generic: profession.append(field)
            }
        }
        let layout = TreatmentFormLayout.split(profession, draft: draft)
        return VisitFormSections(
            quickNote: quickNote, profession: layout.main, moreProfession: layout.more, result: result,
            guidance: guidance
        )
    }
}
