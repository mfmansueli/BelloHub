//
//  IncidentRules.swift
//  BelloHub
//

import Foundation

/// Turns the incident sheet's choices into the `Incident` the vault stores, and says whether it can be saved.
enum IncidentRules {
    /// At least one symptom: an incident with nothing in it is not a note.
    static func canSave(_ draft: IncidentDraft) -> Bool {
        !draft.symptoms.isEmpty
    }

    /// `resolve` turns a title into the text in her language; the vault keeps those words, encrypted, as she read them.
    /// Her notes go after the symptoms, so one field holds what happened.
    static func incident(
        from draft: IncidentDraft, clientID: UUID, id: UUID, now: Date, resolve: (LocalizedStringResource) -> String
    ) -> Incident {
        let symptoms = IncidentSymptom.allCases.filter { draft.symptoms.contains($0) }.map { resolve($0.title) }
        let actions = IncidentAction.allCases.filter { draft.actions.contains($0) }.map { resolve($0.title) }
        var what = symptoms.joined(separator: ", ")
        if let notes = RecordEditRules.normalized(draft.notes) { what += ". " + notes }
        return Incident(
            id: id, clientID: clientID, recordID: draft.recordID, occurredAt: now, severity: draft.severity,
            lockedAt: RecordLockPolicy.lockedAt(createdAt: now), needsFollowUp: draft.followUp,
            symptoms: what, area: draft.area.map { resolve($0.title) },
            actionTaken: actions.isEmpty ? nil : actions.joined(separator: ", "), followUp: nil
        )
    }
}
