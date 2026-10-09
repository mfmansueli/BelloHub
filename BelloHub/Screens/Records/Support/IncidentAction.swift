//
//  IncidentAction.swift
//  BelloHub
//

import Foundation

/// What the professional did about it (4.9).
enum IncidentAction: String, CaseIterable, Identifiable, Sendable {
    case removedProduct
    case coldCompress
    case advisedClient
    case referredToDoctor

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .removedProduct: "incident.action.removedProduct"
        case .coldCompress: "incident.action.coldCompress"
        case .advisedClient: "incident.action.advisedClient"
        case .referredToDoctor: "incident.action.referredToDoctor"
        }
    }
}
