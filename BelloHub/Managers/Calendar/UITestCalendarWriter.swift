//
//  UITestCalendarWriter.swift
//  BelloHub
//

#if DEBUG
import Foundation
import os

/// A "Bello Hub" calendar kept in memory, so a UI-test launch can switch Apple Calendar on without touching the
/// simulator's calendar. DEBUG only.
final class UITestCalendarWriter: CalendarEventWriting, Sendable {
    private let stored = OSAllocatedUnfairLock<[String: CalendarEventRecord]>(initialState: [:])

    func events(in range: DateInterval) async throws -> [CalendarEventRecord] {
        stored.withLock { events in events.values.filter { $0.end > range.start && $0.start < range.end } }
    }

    func apply(_ changes: CalendarEventChanges) async throws {
        stored.withLock { events in
            for identifier in changes.deletes { events[identifier] = nil }
            for update in changes.updates { events[update.identifier] = Self.record(update.identifier, update.draft) }
            for draft in changes.creates {
                let identifier = UUID().uuidString
                events[identifier] = Self.record(identifier, draft)
            }
        }
    }

    func removeCalendar() async throws {
        stored.withLock { $0 = [:] }
    }

    private static func record(_ identifier: String, _ draft: CalendarEventDraft) -> CalendarEventRecord {
        CalendarEventRecord(
            identifier: identifier, appointmentID: draft.appointmentID, title: draft.title, start: draft.start,
            end: draft.end
        )
    }
}
#endif
