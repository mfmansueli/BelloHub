//
//  IncidentSeverity.swift
//  BelloHub
//

enum IncidentSeverity: String, PersistedEnum {
    case mild
    case moderate
    case severe

    /// An unknown severity is shown as the most careful one.
    static let fallback = IncidentSeverity.moderate
}
