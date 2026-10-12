//
//  ClientTimelineBuilder.swift
//  BelloHub
//

import Foundation

/// Builds a client's timeline from what the vault holds. Everything is grouped by its stored links only: a photo or an
/// incident belongs to a visit when its `recordID` is that record, a record to an appointment when its
/// `appointmentID` is that appointment. Two things on the same day are never joined because of the date.
enum ClientTimelineBuilder {
    struct Input: Sendable {
        var records: [TreatmentRecord] = []
        var corrections: [RecordCorrection] = []
        var appointments: [Appointment] = []
        var photos: [Photo] = []
        var incidents: [Incident] = []
    }

    static func make(_ input: Input, now: Date, list: ([String]) -> String) -> ClientTimeline {
        let appointmentsByID = Dictionary(
            input.appointments.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        let recordIDs = Set(input.records.map(\.id))
        let photosByRecord = Dictionary(grouping: input.photos.filter { $0.recordID.map(recordIDs.contains) == true },
                                        by: { $0.recordID ?? UUID() })
        let incidentsByRecord = Dictionary(
            grouping: input.incidents.filter { $0.recordID.map(recordIDs.contains) == true },
            by: { $0.recordID ?? UUID() }
        )

        let visits = input.records.map { stored -> VisitSummary in
            let current = RecordCurrentValues(record: stored, corrections: input.corrections)
            let record = current.applied
            return VisitSummary(
                record: record,
                visitDate: current.visitDate(appointments: appointmentsByID),
                photos: (photosByRecord[stored.id] ?? []).sorted(by: oldestFirst),
                incidents: (incidentsByRecord[stored.id] ?? []).sorted { $0.occurredAt < $1.occurredAt },
                state: VisitRecordState.of(stored, now: now),
                summary: VisitSummaryText.make(record, list: list)
            )
        }

        var entries = visits.map(ClientTimelineEntry.visit)
        let recorded = RecordForAppointment.recordedAppointmentIDs(input.records)
        entries += bookingEntries(input.appointments, recorded: recorded, now: now)
        entries += input.incidents
            .filter { $0.recordID.map(recordIDs.contains) != true }
            .map(ClientTimelineEntry.incident)
        entries.sort { lhs, rhs in
            lhs.date == rhs.date ? (lhs.rank, lhs.id) < (rhs.rank, rhs.id) : lhs.date > rhs.date
        }

        return ClientTimeline(
            entries: entries,
            lastVisit: entries.lazy.compactMap { entry -> VisitSummary? in
                guard case .visit(let visit) = entry else { return nil }
                return visit
            }.first,
            unlinkedPhotos: input.photos
                .filter { $0.recordID.map(recordIDs.contains) != true }
                .sorted { $0.takenAt > $1.takenAt }
        )
    }

    /// Past bookings that did not become a record: completed ones wait for their record, cancelled ones and no-shows
    /// are shown for what they are. Future bookings and the ones still running are not history yet.
    private static func bookingEntries(
        _ appointments: [Appointment], recorded: Set<UUID>, now: Date
    ) -> [ClientTimelineEntry] {
        appointments.compactMap { appointment -> ClientTimelineEntry? in
            guard !recorded.contains(appointment.id) else { return nil }
            switch appointment.status {
            case .completed:
                return .pendingRecord(appointment)
            case .cancelled, .noShow:
                return appointment.startsAt <= now ? .notHeld(appointment) : nil
            case .booked, .confirmed:
                return nil
            }
        }
    }

    private static func oldestFirst(_ lhs: Photo, _ rhs: Photo) -> Bool {
        lhs.takenAt == rhs.takenAt ? lhs.id.uuidString < rhs.id.uuidString : lhs.takenAt < rhs.takenAt
    }
}
