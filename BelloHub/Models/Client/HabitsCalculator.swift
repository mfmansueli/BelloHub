//
//  HabitsCalculator.swift
//  BelloHub
//

import Foundation

/// Computes `ClientHabits` (docs/05-DATA-MODEL.md, "Derived, never stored"). Pure: `now` and the calendar are inputs.
enum HabitsCalculator {
    static func habits(for clientID: UUID, appointments all: [Appointment], now: Date, calendar: Calendar)
        -> ClientHabits {
        let appointments = all.filter { $0.clientID == clientID }
        let completed = appointments.filter { $0.status == .completed }.sorted { $0.startsAt < $1.startsAt }
        let cancelledByClient = appointments.filter { $0.status == .cancelled && $0.cancelledBy == .client }
        let noShows = appointments.filter { $0.status == .noShow && !$0.noShowForgiven }
        let rate = rate(appointments: appointments, now: now)
        let visits = completed.count

        return ClientHabits(
            visits: visits,
            cancelled: cancelledByClient.count,
            noShows: noShows.count,
            lateCancellations: cancelledByClient.filter(\.isLateCancellation).count,
            cancellationRate: visits >= ClientHabits.minimumVisitsForRate ? rate : nil,
            cancelsOften: visits >= ClientHabits.minimumVisitsForRate
                && (rate ?? 0) >= ClientHabits.cancelsOftenThreshold,
            returnsEveryWeeks: returnsEveryWeeks(completed: completed, calendar: calendar),
            usualPeriod: usualPeriod(appointments: appointments, calendar: calendar),
            mostBookedService: mostBookedService(appointments: appointments),
            lastVisit: completed.last?.startsAt,
            reminderResponseDays: reminderResponseDays(appointments: appointments)
        )
    }

    // MARK: - Rate

    /// (cancellations by the client + no-shows) / past appointments, among the last ten. A cancellation by the
    /// professional and a forgiven no-show are left out of both sides.
    private static func rate(appointments: [Appointment], now: Date) -> Double? {
        let counted = appointments
            .filter { $0.startsAt < now && isCounted($0) }
            .sorted { $0.startsAt > $1.startsAt }
            .prefix(ClientHabits.rateWindow)
        guard !counted.isEmpty else { return nil }
        let missed = counted.filter { $0.status == .cancelled || $0.status == .noShow }.count
        return Double(missed) / Double(counted.count)
    }

    private static func isCounted(_ appointment: Appointment) -> Bool {
        switch appointment.status {
        case .completed: true
        case .cancelled: appointment.cancelledBy == .client
        case .noShow: !appointment.noShowForgiven
        case .booked, .confirmed: false
        }
    }

    // MARK: - Rhythm

    /// Median gap between consecutive completed visits, in whole weeks.
    private static func returnsEveryWeeks(completed: [Appointment], calendar: Calendar) -> Int? {
        guard completed.count >= 2 else { return nil }
        let gaps = zip(completed, completed.dropFirst()).map { previous, next -> Double in
            let from = calendar.startOfDay(for: previous.startsAt)
            let to = calendar.startOfDay(for: next.startsAt)
            return Double(calendar.dateComponents([.day], from: from, to: to).day ?? 0)
        }
        return Int((median(gaps) / 7).rounded())
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// The most common part of the day among visits she kept or still holds. Ties go to the earlier part.
    private static func usualPeriod(appointments: [Appointment], calendar: Calendar) -> DayPeriod? {
        let kept = appointments.filter { $0.status == .completed || $0.status.holdsTime }
        let counts = Dictionary(grouping: kept) { DayPeriod(hour: calendar.component(.hour, from: $0.startsAt)) }
            .mapValues(\.count)
        guard let top = counts.values.max() else { return nil }
        return DayPeriod.allCases.first { counts[$0] == top }
    }

    /// The service she books most; on a tie, the one she booked more recently.
    private static func mostBookedService(appointments: [Appointment]) -> String? {
        let booked = appointments.filter { $0.status == .completed || $0.status.holdsTime }
        let groups = Dictionary(grouping: booked, by: \.serviceName)
        return groups.max { left, right in
            if left.value.count != right.value.count { return left.value.count < right.value.count }
            let leftLatest = left.value.map(\.startsAt).max() ?? .distantPast
            let rightLatest = right.value.map(\.startsAt).max() ?? .distantPast
            return leftLatest < rightLatest
        }?.key
    }

    private static func reminderResponseDays(appointments: [Appointment]) -> Double? {
        let gaps = appointments.compactMap { appointment -> Double? in
            guard let sent = appointment.reminderSentAt, let confirmed = appointment.clientConfirmedAt,
                  confirmed >= sent else { return nil }
            return confirmed.timeIntervalSince(sent) / 86_400
        }
        guard !gaps.isEmpty else { return nil }
        return gaps.reduce(0, +) / Double(gaps.count)
    }
}
