//
//  ServiceEditorMode.swift
//  BelloHub
//

import Foundation

/// What the service form is for: a new service, or one she is changing or deleting. It is the `item` of the sheet, so
/// SwiftUI builds a fresh form (and fresh field state) for each service.
enum ServiceEditorMode: Identifiable, Equatable, Sendable {
    case add
    case edit(Service)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let service): service.id.uuidString
        }
    }

    /// The service being edited, nil when adding.
    var service: Service? {
        if case .edit(let service) = self { return service }
        return nil
    }
}
