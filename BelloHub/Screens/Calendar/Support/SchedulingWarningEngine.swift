//
//  SchedulingWarningEngine.swift
//  BelloHub
//

import Foundation

/// What the engine looks at for one visit that is about to be booked or moved.
struct SchedulingWarningInput: Sendable {
    /// The visit's real interval (start and end).
    var interval: DateInterval
    var settings: AvailabilitySettings
    /// Every visit that may be near it. Cancelled visits and no-shows do not hold time and are ignored; the visit
    /// being moved is named in `ignoring`.
    var appointments: [Appointment]
    var blocks: [TimeBlock]
    var service: Service?
    var clientID: UUID?
    /// All of the client's visits, for her habits.
    var clientAppointments: [Appointment] = []
    /// Her latest health form (nil when she has none) and the catalog its answers are read against.
    var form: HealthForm?
    var catalog: HealthFormCatalog?
    var patchTests: [PatchTest] = []
    var ignoring: UUID?
    var now: Date
}

/// The warnings of a new visit (overlap, break, end of day, buffer, missing patch test, contraindication, a client who
/// cancels often). Pure: the time zone is the business one and `now` is an input, so every case is a table test,
/// also on a daylight-saving change day.
enum SchedulingWarningEngine {
    static func warnings(for input: SchedulingWarningInput) -> [SchedulingWarning] {
        let found = timeWarnings(input) + clientWarnings(input)
        return found.sorted { $0.rank < $1.rank }
    }

    // MARK: - Time

    private static func timeWarnings(_ input: SchedulingWarningInput) -> [SchedulingWarning] {
        var found: [SchedulingWarning] = []
        let interval = input.interval
        if interval.start < input.now { found.append(.inThePast) }

        let holding = input.appointments.filter {
            $0.id != input.ignoring && $0.status != .cancelled && $0.status != .noShow
        }
        for other in holding where overlaps(interval, other.interval) { found.append(.overlap(with: other.id)) }
        if input.blocks.contains(where: { overlaps(interval, $0.interval) }) { found.append(.blocked) }
        found += hoursWarnings(input)
        found += bufferWarnings(input, holding: holding)
        return found
    }

    private static func hoursWarnings(_ input: SchedulingWarningInput) -> [SchedulingWarning] {
        let settings = input.settings
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        let dayStart = calendar.startOfDay(for: input.interval.start)
        if FreeSlotsCalculator.dayOff(on: dayStart, settings: settings, calendar: calendar) != nil { return [.dayOff] }

        let windows = FreeSlotsCalculator.workingWindows(on: dayStart, settings: settings)
        guard let first = windows.first, let last = windows.last else { return [.closedDay] }
        var found: [SchedulingWarning] = []
        if !windows.contains(where: { $0.start <= input.interval.start && input.interval.end <= $0.end }) {
            if input.interval.start < first.start {
                found.append(.outsideHours(.beforeOpening))
            } else if input.interval.end > last.end {
                found.append(.outsideHours(.afterClosing))
            } else {
                found.append(.outsideHours(.betweenStretches))
            }
        }
        for item in FreeSlotsCalculator.breakWindows(on: dayStart, settings: settings)
        where overlaps(input.interval, item.interval) {
            found.append(.insideBreak(label: item.label))
        }
        return found
    }

    /// A neighbour closer than the buffer, without touching the visit (touching is already an overlap warning).
    private static func bufferWarnings(_ input: SchedulingWarningInput, holding: [Appointment]) -> [SchedulingWarning] {
        let buffer = TimeInterval(input.settings.bufferMinutes * 60)
        guard buffer > 0 else { return [] }
        let interval = input.interval
        return holding.compactMap { other in
            guard !overlaps(interval, other.interval) else { return nil }
            let gap = other.startsAt >= interval.end
                ? other.startsAt.timeIntervalSince(interval.end)
                : interval.start.timeIntervalSince(other.endsAt)
            guard gap < buffer else { return nil }
            return .buffer(minutes: input.settings.bufferMinutes, neighbour: other.id)
        }
    }

    /// Two stretches overlap when they share some time; ones that only touch do not.
    private static func overlaps(_ first: DateInterval, _ second: DateInterval) -> Bool {
        first.start < second.end && second.start < first.end
    }

    // MARK: - Client and service

    private static func clientWarnings(_ input: SchedulingWarningInput) -> [SchedulingWarning] {
        var found: [SchedulingWarning] = []
        if let service = input.service {
            found += patchTestWarnings(service: service, input: input)
            found += contraindicationWarnings(service: service, input: input)
        }
        if let clientID = input.clientID {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = input.settings.timeZone
            let habits = HabitsCalculator.habits(
                for: clientID, appointments: input.clientAppointments, now: input.now, calendar: calendar
            )
            if habits.cancelsOften {
                found.append(.cancelsOften(cancelled: habits.cancelled, noShows: habits.noShows))
            }
        }
        return found
    }

    /// A patch test counts when it was logged before the visit and showed no reaction. A later test with a reaction
    /// overrides an earlier clean one.
    private static func patchTestWarnings(service: Service, input: SchedulingWarningInput) -> [SchedulingWarning] {
        guard service.requiresPatchTest else { return [] }
        let earlier = input.patchTests.filter { $0.testedAt <= input.interval.start }
            .sorted { $0.testedAt > $1.testedAt }
        guard let latest = earlier.first else { return [.missingPatchTest(hoursBefore: service.patchTestHoursBefore)] }
        return latest.result.needsAttention ? [.patchTestReaction] : []
    }

    private static func contraindicationWarnings(
        service: Service, input: SchedulingWarningInput
    ) -> [SchedulingWarning] {
        guard !service.contraindications.isEmpty, let catalog = input.catalog else { return [] }
        let report = ContraindicationMatcher.check(
            contraindications: service.contraindications, form: input.form, catalog: catalog
        )
        if report.hasWarnings { return [.contraindicated(report.matches)] }
        // Nothing can be said without a form, and that is worth a line: an empty result there means "unknown".
        return input.form == nil ? [.noHealthForm] : []
    }
}
