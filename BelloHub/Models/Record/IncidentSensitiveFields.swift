//
//  IncidentSensitiveFields.swift
//  BelloHub
//

/// The encrypted part of an `Incident`.
struct IncidentSensitiveFields: Codable, Equatable, Sendable {
    var symptoms: String?
    var area: String?
    var actionTaken: String?
    var followUp: String?

    init(_ incident: Incident) {
        symptoms = incident.symptoms
        area = incident.area
        actionTaken = incident.actionTaken
        followUp = incident.followUp
    }
}
