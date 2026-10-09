//
//  IncidentSymptom.swift
//  BelloHub
//

import Foundation

/// What the client reported or the professional saw (4.9). A closed list keeps the note clear and neutral.
enum IncidentSymptom: String, CaseIterable, Identifiable, Sendable {
    case redness
    case swelling
    case burning
    case itching
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .redness: "incident.symptom.redness"
        case .swelling: "incident.symptom.swelling"
        case .burning: "incident.symptom.burning"
        case .itching: "incident.symptom.itching"
        case .other: "incident.option.other"
        }
    }
}
