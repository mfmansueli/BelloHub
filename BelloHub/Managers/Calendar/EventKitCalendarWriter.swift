//
//  EventKitCalendarWriter.swift
//  BelloHub
//

import EventKit

/// EventKit as `CalendarEventWriting`: one calendar named "Bello Hub" in her default calendar account (iCloud when she
/// uses it, so it follows her like the vault does), holding one event per visit with no alarm and no notes. An actor,
/// because `EKEventStore` is not `Sendable` and its reads and commits should stay off the main actor.
actor EventKitCalendarWriter: CalendarEventWriting {
    /// The calendar's name, a brand name in every language.
    static let calendarTitle = "Bello Hub"

    /// Created on first use: a store made before she granted access would not see her calendars.
    private var storage: EKEventStore?

    private var store: EKEventStore {
        if let storage { return storage }
        let made = EKEventStore()
        storage = made
        return made
    }

    func events(in range: DateInterval) throws -> [CalendarEventRecord] {
        guard let calendar = existingCalendar() else { return [] }
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: [calendar])
        return store.events(matching: predicate).map { event in
            CalendarEventRecord(
                identifier: event.eventIdentifier ?? "",
                appointmentID: CalendarEventPlanner.appointmentID(from: event.url), title: event.title ?? "",
                start: event.startDate, end: event.endDate
            )
        }
    }

    func apply(_ changes: CalendarEventChanges) throws {
        guard !changes.isEmpty else { return }
        let calendar = try ensureCalendar()
        for draft in changes.creates {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            fill(event, with: draft)
            try store.save(event, span: .thisEvent, commit: false)
        }
        for update in changes.updates {
            guard let event = store.event(withIdentifier: update.identifier) else { continue }
            fill(event, with: update.draft)
            try store.save(event, span: .thisEvent, commit: false)
        }
        for identifier in changes.deletes {
            guard let event = store.event(withIdentifier: identifier) else { continue }
            try store.remove(event, span: .thisEvent, commit: false)
        }
        try store.commit()
    }

    func removeCalendar() throws {
        guard let calendar = existingCalendar() else { return }
        try store.removeCalendar(calendar, commit: true)
    }

    // MARK: - Private

    private func fill(_ event: EKEvent, with draft: CalendarEventDraft) {
        event.title = draft.title
        event.startDate = draft.start
        event.endDate = draft.end
        event.url = CalendarEventPlanner.url(for: draft.appointmentID)
    }

    private func existingCalendar() -> EKCalendar? {
        store.calendars(for: .event).first { $0.title == Self.calendarTitle && $0.allowsContentModifications }
    }

    private func ensureCalendar() throws -> EKCalendar {
        if let calendar = existingCalendar() { return calendar }
        guard let source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first(where: { $0.sourceType == .local }) else {
            throw CalendarWriteError.noSource
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = Self.calendarTitle
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }
}
