//
//  IncidentRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("IncidentRules")
struct IncidentRulesTests {
    private let clientID = UUID()
    private let resolve: (LocalizedStringResource) -> String = { String(describing: $0.key) }

    @Test("The prototype's defaults are a note that can be saved")
    func defaultsCanBeSaved() {
        #expect(IncidentRules.canSave(IncidentDraft()))
    }

    @Test("With no symptom there is nothing to save")
    func needsASymptom() {
        var draft = IncidentDraft()
        draft.symptoms = []
        #expect(IncidentRules.canSave(draft) == false)
    }

    @Test("The incident carries the choices in a fixed order, locks 24 hours later and keeps the visit")
    func incidentContent() {
        let visit = UUID()
        var draft = IncidentDraft()
        draft.recordID = visit
        draft.symptoms = [.swelling, .redness]
        draft.severity = .moderate
        draft.area = .neck
        draft.actions = [.referredToDoctor, .coldCompress]
        draft.followUp = false
        let id = UUID()
        let incident = IncidentRules.incident(
            from: draft, clientID: clientID, id: id, now: TestClock.now, resolve: resolve
        )
        #expect(incident.id == id)
        #expect(incident.clientID == clientID)
        #expect(incident.recordID == visit)
        #expect(incident.occurredAt == TestClock.now)
        #expect(incident.lockedAt == TestClock.now.addingTimeInterval(24 * 3600))
        #expect(incident.severity == .moderate)
        #expect(incident.needsFollowUp == false)
        #expect(incident.symptoms == "incident.symptom.redness, incident.symptom.swelling")
        #expect(incident.area == "incident.area.neck")
        #expect(incident.actionTaken == "incident.action.coldCompress, incident.action.referredToDoctor")
    }

    @Test("Notes follow the symptoms in the same field, trimmed; blank notes add nothing")
    func notes() {
        var draft = IncidentDraft()
        draft.notes = "  Appeared an hour later  "
        let withNotes = IncidentRules.incident(
            from: draft, clientID: clientID, id: UUID(), now: TestClock.now, resolve: resolve
        )
        #expect(withNotes.symptoms == "incident.symptom.redness. Appeared an hour later")
        draft.notes = "   "
        let blank = IncidentRules.incident(
            from: draft, clientID: clientID, id: UUID(), now: TestClock.now, resolve: resolve
        )
        #expect(blank.symptoms == "incident.symptom.redness")
    }

    @Test("No area and no action are stored as nothing")
    func optionalParts() {
        var draft = IncidentDraft()
        draft.area = nil
        draft.actions = []
        let incident = IncidentRules.incident(
            from: draft, clientID: clientID, id: UUID(), now: TestClock.now, resolve: resolve
        )
        #expect(incident.area == nil)
        #expect(incident.actionTaken == nil)
    }
}
