//
//  PatchTestRules.swift
//  BelloHub
//

import Foundation

/// The rules of recording a patch test. Pure.
enum PatchTestRules {
    /// A patch test needs to say what was tested.
    static func canSave(_ draft: PatchTestDraft) -> Bool {
        draft.product.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
            && PatchTest.observationOptions.contains(draft.observedHours)
    }

    /// The entry the sheet saves. Empty optional text is stored as nothing, not as an empty string.
    static func patchTest(from draft: PatchTestDraft, clientID: UUID, id: UUID) -> PatchTest {
        func optional(_ text: String) -> String? {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return PatchTest(
            id: id, clientID: clientID, testedAt: draft.testedAt, observedHours: draft.observedHours,
            product: draft.product.trimmingCharacters(in: .whitespacesAndNewlines), area: optional(draft.area),
            result: draft.result, notes: optional(draft.notes)
        )
    }
}
