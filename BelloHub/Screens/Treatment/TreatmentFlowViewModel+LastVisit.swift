//
//  TreatmentFlowViewModel+LastVisit.swift
//  BelloHub
//

import Foundation

/// "Same as last visit" on the manual form (routine-a item 8): her own answers from the client's latest record of the
/// same service, for the fields still empty. The rule is `LastVisitPrefill`'s.
extension TreatmentFlowViewModel {
    /// What "Same as last visit" would fill in now (empty when there is nothing to offer).
    var lastVisitValues: [String: String] {
        guard let lastVisit else { return [:] }
        return LastVisitPrefill.values(from: lastVisit, fields: fields, draft: draft)
    }

    /// Fills the empty fields with her answers of the last visit; what she already typed is kept.
    func applyLastVisit() {
        for (key, value) in lastVisitValues { draft.set(value, for: key) }
        draftChanged()
    }
}
