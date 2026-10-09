//
//  IncidentArea.swift
//  BelloHub
//

import Foundation

/// Where on the body the reaction is (4.9).
enum IncidentArea: String, CaseIterable, Identifiable, Sendable {
    case cheeks
    case forehead
    case chin
    case neck
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .cheeks: "incident.area.cheeks"
        case .forehead: "incident.area.forehead"
        case .chin: "incident.area.chin"
        case .neck: "incident.area.neck"
        case .other: "incident.option.other"
        }
    }
}
