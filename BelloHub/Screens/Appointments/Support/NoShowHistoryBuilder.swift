//
//  NoShowHistoryBuilder.swift
//  BelloHub
//

import Foundation

/// Turns a client's appointments into the lines of her no-show history (4.11), newest first. What counts is decided by
/// `NoShowEvaluator`; this only labels each line with why it does or does not count.
enum NoShowHistoryBuilder {
    static func entries(
        policy: NoShowPolicy, client: Client, appointments: [Appointment], now: Date, calendar: Calendar
    ) -> [NoShowHistoryEntry] {
        let since = NoShowEvaluator.windowStart(policy: policy, client: client, now: now, calendar: calendar)
        return appointments
            .filter { $0.clientID == client.id }
            .compactMap { entry(for: $0, policy: policy, since: since, now: now) }
            .sorted { ($0.startsAt, $0.id.uuidString) > ($1.startsAt, $1.id.uuidString) }
    }

    private static func entry(
        for appointment: Appointment, policy: NoShowPolicy, since: Date, now: Date
    ) -> NoShowHistoryEntry? {
        let kind: NoShowHistoryEntry.Kind
        switch appointment.status {
        case .noShow:
            kind = .noShow
        case .cancelled where appointment.cancelledBy == .client && appointment.isLateCancellation:
            kind = .lateCancellation
        default:
            return nil
        }
        return NoShowHistoryEntry(
            id: appointment.id, startsAt: appointment.startsAt, serviceName: appointment.serviceName, kind: kind,
            standing: standing(of: appointment, kind: kind, policy: policy, since: since, now: now)
        )
    }

    private static func standing(
        of appointment: Appointment, kind: NoShowHistoryEntry.Kind, policy: NoShowPolicy, since: Date, now: Date
    ) -> NoShowHistoryEntry.Standing {
        if kind == .noShow, appointment.noShowForgiven { return .forgiven }
        if kind == .lateCancellation, !policy.lateCancelCounts { return .notCounted }
        guard appointment.startsAt >= since, appointment.startsAt <= now else { return .expired }
        return .counts
    }
}
