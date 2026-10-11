//
//  InMemoryClientRecordRepository+BookingSetup.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// What the in-memory vault holds for the booking setup. A struct of its own so the actor's main file takes one line
/// for it (a stored property cannot live in an extension, and that file is at SwiftLint's type-body limit).
struct BookingSetupMemory: Sendable {
    var availability: AvailabilitySettings?
    var setup: BookingSetup?
    var quickRepliesByID: [UUID: QuickReply] = [:]
    /// The message log (S6) rides here for the same reason: the actor's main file takes no more stored properties.
    var messageLogsByID: [UUID: MessageLog] = [:]
}

extension InMemoryClientRecordRepository {
    func availability() -> AvailabilitySettings? {
        bookingSetupMemory.availability
    }

    func save(_ availability: AvailabilitySettings) {
        bookingSetupMemory.availability = availability
        changes.notify()
    }

    func bookingSetup() -> BookingSetup? {
        bookingSetupMemory.setup
    }

    func save(_ setup: BookingSetup) {
        var stored = setup
        stored.updatedAt = clock()
        bookingSetupMemory.setup = stored
        changes.notify()
    }

    func quickReplies() -> [QuickReply] {
        bookingSetupMemory.quickRepliesByID.values.sorted {
            ($0.position, $0.title, $0.id.uuidString) < ($1.position, $1.title, $1.id.uuidString)
        }
    }

    func save(_ reply: QuickReply) {
        bookingSetupMemory.quickRepliesByID[reply.id] = reply
        changes.notify()
    }

    func save(_ replies: [QuickReply]) {
        replies.forEach { bookingSetupMemory.quickRepliesByID[$0.id] = $0 }
        changes.notify()
    }

    func deleteQuickReply(id: UUID) {
        bookingSetupMemory.quickRepliesByID[id] = nil
        changes.notify()
    }
}
#endif
