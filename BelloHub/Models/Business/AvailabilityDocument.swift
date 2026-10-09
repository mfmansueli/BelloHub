//
//  AvailabilityDocument.swift
//  BelloHub
//

import Foundation

/// `AvailabilitySettings` as the vault stores it: one per vault, so it needs an identity of its own. Kept apart from
/// the settings so the free-slot calculation, which is shared with the server, stays free of storage.
struct AvailabilityDocument: Identifiable, Hashable, Codable, Sendable {
    static let singletonID = UUID(uuidString: "B3110000-0000-4000-8000-000000000004") ?? UUID()

    let id: UUID
    var settings: AvailabilitySettings
    var updatedAt: Date

    init(settings: AvailabilitySettings, updatedAt: Date) {
        self.id = Self.singletonID
        self.settings = settings
        self.updatedAt = updatedAt
    }
}
