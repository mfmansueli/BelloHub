//
//  IncidentSeverity+Title.swift
//  BelloHub
//

import Foundation

extension IncidentSeverity {
    var title: LocalizedStringResource {
        switch self {
        case .mild: "incident.severity.mild"
        case .moderate: "incident.severity.moderate"
        case .severe: "incident.severity.severe"
        }
    }
}
