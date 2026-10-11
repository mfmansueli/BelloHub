//
//  CalendarEventPlanner.swift
//  BelloHub
//

import Foundation

/// The rules of the Apple Calendar write-through (7.6), with no IO: which visits become events, what the events say,
/// and what has to change in the calendar so it matches her visits. The calendar is only a mirror: the vault stays the
/// source of truth, and anything in the "Bello Hub" calendar that is not one of her visits is removed.
enum CalendarEventPlanner {
    /// The stretch mirrored: from yesterday to three months ahead. Older visits are history (the record has them).
    static let daysBefore = 1
    static let daysAfter = 90

    static func window(now: Date) -> DateInterval {
        DateInterval(
            start: now.addingTimeInterval(-TimeInterval(daysBefore * 86_400)),
            end: now.addingTimeInterval(TimeInterval(daysAfter * 86_400))
        )
    }

    /// The events her visits should have. Cancelled visits and no-shows leave the calendar. The title carries the
    /// client's name and the service only when she lets names appear on the lock screen (Privacy, docs/06 section 4.4),
    /// because the iPhone shows the next event on the lock screen and in widgets; otherwise it is `genericTitle`.
    static func drafts(
        appointments: [Appointment], clientNames: [UUID: String], showsNames: Bool, genericTitle: String
    ) -> [CalendarEventDraft] {
        appointments
            .filter { $0.status != .cancelled && $0.status != .noShow }
            .map { visit in
                CalendarEventDraft(
                    appointmentID: visit.id,
                    title: title(for: visit, clientName: clientNames[visit.clientID], showsNames: showsNames,
                                 genericTitle: genericTitle),
                    start: visit.startsAt, end: visit.endsAt
                )
            }
            .sorted { ($0.start, $0.appointmentID.uuidString) < ($1.start, $1.appointmentID.uuidString) }
    }

    /// What to add, change and remove so `existing` (the "Bello Hub" calendar) matches `drafts`. An event of no visit,
    /// or a second event of the same visit, is removed.
    static func changes(drafts: [CalendarEventDraft], existing: [CalendarEventRecord]) -> CalendarEventChanges {
        var changes = CalendarEventChanges()
        var byVisit: [UUID: CalendarEventRecord] = [:]
        let wanted = Set(drafts.map(\.appointmentID))
        for record in existing.sorted(by: { $0.identifier < $1.identifier }) {
            guard let id = record.appointmentID, wanted.contains(id), byVisit[id] == nil else {
                changes.deletes.append(record.identifier)
                continue
            }
            byVisit[id] = record
        }
        for draft in drafts {
            guard let record = byVisit[draft.appointmentID] else {
                changes.creates.append(draft)
                continue
            }
            if record.title != draft.title || record.start != draft.start || record.end != draft.end {
                changes.updates.append(.init(identifier: record.identifier, draft: draft))
            }
        }
        return changes
    }

    // MARK: - Event address

    private static let scheme = "bellohub-visit"

    /// The address stored on an event so the next pass knows which visit it mirrors. It carries the visit's random id
    /// only, never a name.
    static func url(for appointmentID: UUID) -> URL? {
        URL(string: "\(scheme):\(appointmentID.uuidString)")
    }

    static func appointmentID(from url: URL?) -> UUID? {
        guard let url, url.scheme == scheme else { return nil }
        return UUID(uuidString: String(url.absoluteString.dropFirst(scheme.count + 1)))
    }

    // MARK: - Private

    private static func title(
        for visit: Appointment, clientName: String?, showsNames: Bool, genericTitle: String
    ) -> String {
        guard showsNames, let name = clientName?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
            return genericTitle
        }
        return "\(name) · \(visit.serviceName)"
    }
}
