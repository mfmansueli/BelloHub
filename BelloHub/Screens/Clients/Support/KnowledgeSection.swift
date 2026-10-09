//
//  KnowledgeSection.swift
//  BelloHub
//

import Foundation

/// The three lists of what she remembers about a client (4.4). Each is a list of short entries in her own words,
/// encrypted at rest with the rest of the client's private notes.
enum KnowledgeSection: String, CaseIterable, Identifiable, Sendable {
    case sensitivities
    case preferences
    case recurringRequests

    var id: String { rawValue }

    func entries(of client: Client) -> [String] {
        switch self {
        case .sensitivities: client.sensitivities
        case .preferences: client.preferences
        case .recurringRequests: client.recurringRequests
        }
    }

    func setEntries(_ entries: [String], on client: inout Client) {
        switch self {
        case .sensitivities: client.sensitivities = entries
        case .preferences: client.preferences = entries
        case .recurringRequests: client.recurringRequests = entries
        }
    }
}
