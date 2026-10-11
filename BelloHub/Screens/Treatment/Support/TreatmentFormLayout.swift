//
//  TreatmentFormLayout.swift
//  BelloHub
//

import Foundation

/// Which questions of the manual form show at once and which wait under "More fields" (routine-a item 8): the
/// observations, the fields with a place in the record (products, technique, result, aftercare) and the first few of
/// her own; a field that already has an answer always shows. Nothing is required but one answer. Pure.
enum TreatmentFormLayout {
    /// How many of her template's own fields show before "More fields".
    static let leadingGenericCount = 2

    static func split(
        _ fields: [TreatmentFormField], draft: TreatmentDraft
    ) -> (main: [TreatmentFormField], more: [TreatmentFormField]) {
        var main: [TreatmentFormField] = []
        var more: [TreatmentFormField] = []
        var generic = 0
        for field in fields {
            let answered = !draft.value(for: field.key).isEmpty
            if field.role != .generic || answered {
                main.append(field)
            } else if generic < leadingGenericCount {
                generic += 1
                main.append(field)
            } else {
                more.append(field)
            }
        }
        return (main, more)
    }
}
