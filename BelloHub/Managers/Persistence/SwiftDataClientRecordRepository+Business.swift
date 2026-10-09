//
//  SwiftDataClientRecordRepository+Business.swift
//  BelloHub
//

import Foundation

extension SwiftDataClientRecordRepository {
    func profile() throws -> ProfessionalProfile? {
        guard let stored = try item(kind: .profile, id: ProfessionalProfile.singletonID) else { return nil }
        return try value(ProfessionalProfile.self, from: stored)
    }

    func save(_ profile: ProfessionalProfile) throws {
        var stored = profile
        stored.updatedAt = clock()
        try upsert(stored)
        try commit()
    }

    func tags() throws -> [Tag] {
        try values(Tag.self, from: items(kind: .tag)).sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }

    func save(_ tag: Tag) throws {
        try upsert(tag)
        try commit()
    }

    func save(_ tags: [Tag]) throws {
        // One context save at the end, so a reorder is a single transaction.
        try tags.forEach { try upsert($0) }
        try commit()
    }

    func deleteTag(id: UUID) throws {
        if let found = try item(kind: .tag, id: id) { delete([found]) }
        try commit()
    }

    func deleteTagRemovingFromClients(id: UUID) throws -> Int {
        // Clients are re-sealed through `upsert`, not `save(_ client:)`, so the registration ledger is not touched.
        // A client that cannot be read is skipped (see `values`): it keeps a dangling id, which readers ignore.
        var removed = 0
        for var client in try values(Client.self, from: items(kind: .client)) where client.tagIDs.contains(id) {
            client.tagIDs.removeAll { $0 == id }
            client.updatedAt = clock()
            try upsert(client)
            removed += 1
        }
        if let found = try item(kind: .tag, id: id) { delete([found]) }
        // The clients and the tag go in one context save: one transaction.
        try commit()
        return removed
    }

    func recordTemplate() throws -> RecordTemplate? {
        guard let stored = try item(kind: .recordTemplate, id: RecordTemplate.singletonID) else { return nil }
        return try value(RecordTemplate.self, from: stored)
    }

    func save(_ template: RecordTemplate) throws {
        var stored = template
        stored.updatedAt = clock()
        try upsert(stored)
        try commit()
    }

    func saveOnboarding(_ result: OnboardingResult) throws {
        // One context save at the end: SwiftData writes the inserts as a single transaction.
        try upsert(result.profile)
        try result.services.forEach { try upsert($0) }
        try result.tags.forEach { try upsert($0) }
        try upsert(result.template)
        try commit()
    }
}
