//
//  IncidentDraft.swift
//  BelloHub
//

import Foundation

/// What she has chosen and typed on the incident sheet. The defaults are the prototype's: redness, mild, cheeks,
/// advised the client, follow up on.
struct IncidentDraft: Equatable {
    var recordID: UUID?
    var symptoms: Set<IncidentSymptom> = [.redness]
    var severity: IncidentSeverity = .mild
    var area: IncidentArea? = .cheeks
    var actions: Set<IncidentAction> = [.advisedClient]
    var notes = ""
    var followUp = true
}
