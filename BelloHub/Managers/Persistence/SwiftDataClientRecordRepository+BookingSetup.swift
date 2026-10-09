//
//  SwiftDataClientRecordRepository+BookingSetup.swift
//  BelloHub
//

import Foundation

extension SwiftDataClientRecordRepository {
    func availability() throws -> AvailabilitySettings? {
        guard let stored = try item(kind: .availability, id: AvailabilityDocument.singletonID) else { return nil }
        return try value(AvailabilityDocument.self, from: stored).settings
    }

    func save(_ availability: AvailabilitySettings) throws {
        try upsert(AvailabilityDocument(settings: availability, updatedAt: clock()))
        try commit()
    }

    func bookingSetup() throws -> BookingSetup? {
        guard let stored = try item(kind: .bookingSetup, id: BookingSetup.singletonID) else { return nil }
        return try value(BookingSetup.self, from: stored)
    }

    func save(_ setup: BookingSetup) throws {
        var stored = setup
        stored.updatedAt = clock()
        try upsert(stored)
        try commit()
    }

    func quickReplies() throws -> [QuickReply] {
        try values(QuickReply.self, from: items(kind: .quickReply)).sorted {
            ($0.position, $0.title, $0.id.uuidString) < ($1.position, $1.title, $1.id.uuidString)
        }
    }

    func save(_ reply: QuickReply) throws {
        try upsert(reply)
        try commit()
    }

    func save(_ replies: [QuickReply]) throws {
        // One context save at the end: a reorder or the first defaults are a single transaction.
        try replies.forEach { try upsert($0) }
        try commit()
    }

    func deleteQuickReply(id: UUID) throws {
        if let found = try item(kind: .quickReply, id: id) { delete([found]) }
        try commit()
    }
}
