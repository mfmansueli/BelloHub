//
//  RecordPending.swift
//  BelloHub
//

import Foundation

/// The records still owed, for "To follow up" on Home and in Alerts: completed bookings of the last two weeks with
/// nothing written for them, and drafts she has not finalized. One item per visit: a draft linked to a booking
/// replaces that booking's "nothing written" line, so a visit is never listed twice. Pure: `now`, the calendar and
/// every input are parameters.
struct RecordPending: Equatable, Sendable {
    struct Item: Identifiable, Hashable, Sendable {
        enum Kind: String, Hashable, Sendable {
            /// A completed booking with no record yet: "Register".
            case unwritten
            /// A draft record: "Continue".
            case draft
        }

        let kind: Kind
        let clientID: UUID
        let appointmentID: UUID?
        let recordID: UUID?
        let serviceID: UUID?
        let serviceName: String
        /// The booking's start for an unwritten visit, the day the draft was started otherwise.
        let date: Date

        var id: String { "\(kind.rawValue):\(recordID ?? appointmentID ?? clientID)" }
    }

    /// How far back a completed booking with nothing written is still listed. Older ones stay visible as "Record
    /// pending" on the client's timeline, where they can still be filled.
    static let unwrittenDays = 14

    /// Newest first.
    let items: [Item]

    static let empty = RecordPending(items: [])

    var isEmpty: Bool { items.isEmpty }
    var draftCount: Int { items.filter { $0.kind == .draft }.count }
    var unwrittenCount: Int { items.filter { $0.kind == .unwritten }.count }

    static func make(
        appointments: [Appointment], marks: [RecordMark], clients: [Client], now: Date, calendar: Calendar
    ) -> RecordPending {
        let active = Set(clients.filter { !$0.isArchived }.map(\.id))
        let written = Set(marks.compactMap(\.appointmentID))
        let start = calendar.date(byAdding: .day, value: -unwrittenDays, to: calendar.startOfDay(for: now)) ?? now
        let unwritten = appointments
            .filter {
                $0.status == .completed && $0.startsAt >= start && $0.startsAt <= now
                    && !written.contains($0.id) && active.contains($0.clientID)
            }
            .map {
                Item(kind: .unwritten, clientID: $0.clientID, appointmentID: $0.id, recordID: nil,
                     serviceID: $0.serviceID, serviceName: $0.serviceName, date: $0.startsAt)
            }
        let drafts = marks
            .filter { $0.isDraft && active.contains($0.clientID) }
            .map {
                Item(kind: .draft, clientID: $0.clientID, appointmentID: $0.appointmentID, recordID: $0.id,
                     serviceID: $0.serviceID, serviceName: $0.serviceName, date: $0.createdAt)
            }
        return RecordPending(items: (unwritten + drafts).sorted { $0.date > $1.date })
    }
}
