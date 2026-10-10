//
//  FakeCalendarEventWriter.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import os

/// A "Bello Hub" calendar in memory that records what the write-through asked for, and can be told to fail.
final class FakeCalendarEventWriter: CalendarEventWriting, Sendable {
    private struct State {
        var events: [String: CalendarEventRecord] = [:]
        var applied: [CalendarEventChanges] = []
        var removals = 0
        var fails = false
        var nextID = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var events: [CalendarEventRecord] { state.withLock { Array($0.events.values).sorted { $0.start < $1.start } } }
    var applied: [CalendarEventChanges] { state.withLock { $0.applied } }
    var removals: Int { state.withLock { $0.removals } }

    func setFails(_ fails: Bool) {
        state.withLock { $0.fails = fails }
    }

    /// An event she (or another app) put in the "Bello Hub" calendar by hand.
    func addForeign(_ record: CalendarEventRecord) {
        state.withLock { $0.events[record.identifier] = record }
    }

    func events(in range: DateInterval) async throws -> [CalendarEventRecord] {
        try state.withLock { state in
            if state.fails { throw CalendarWriteError.noSource }
            return state.events.values.filter { $0.end > range.start && $0.start < range.end }
        }
    }

    func apply(_ changes: CalendarEventChanges) async throws {
        try state.withLock { state in
            if state.fails { throw CalendarWriteError.noSource }
            state.applied.append(changes)
            for identifier in changes.deletes { state.events[identifier] = nil }
            for update in changes.updates {
                state.events[update.identifier] = Self.record(update.identifier, update.draft)
            }
            for draft in changes.creates {
                state.nextID += 1
                let identifier = "event-\(state.nextID)"
                state.events[identifier] = Self.record(identifier, draft)
            }
        }
    }

    func removeCalendar() async throws {
        state.withLock { state in
            state.removals += 1
            state.events = [:]
        }
    }

    private static func record(_ identifier: String, _ draft: CalendarEventDraft) -> CalendarEventRecord {
        CalendarEventRecord(
            identifier: identifier, appointmentID: draft.appointmentID, title: draft.title, start: draft.start,
            end: draft.end
        )
    }
}
