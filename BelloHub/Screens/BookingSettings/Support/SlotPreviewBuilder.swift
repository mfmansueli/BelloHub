//
//  SlotPreviewBuilder.swift
//  BelloHub
//

import Foundation

/// Builds the sample day of "What clients see" (routine item 10) from her real settings and services, on the phone,
/// with no server call. It runs the same `FreeSlotsCalculator` her booking page and the server mirror use (D56), so
/// the preview never invents a rule:
/// - the day is her next working day after `now` (her weekly hours; days off are ignored so a holiday never hides the
///   preview);
/// - minimum notice and the booking window are left out on purpose: they say *when* a client may book, not *which*
///   times a day offers, and with them a preview of tomorrow would often be empty;
/// - one sample visit of her shortest service sits an hour after she opens, so the times anchor around a booking the
///   way they do on a real day (no sample visit when she has no services or it does not fit);
/// - the previewed service is the one she picks, or her longest active service; with no services, a plain 60 minutes.
enum SlotPreviewBuilder {
    /// How far ahead the next working day is looked for.
    static let lookaheadDays = 14
    /// Where the sample visit starts, after she opens.
    static let sampleVisitOffsetMinutes = 60
    /// The visit length used when she has no services yet.
    static let fallbackMinutes = 60

    static func preview(
        settings: AvailabilitySettings, services: [Service], previewing serviceID: UUID? = nil, now: Date
    ) -> SlotPreview? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        guard let day = nextWorkingDay(after: now, settings: settings, calendar: calendar) else { return nil }

        let active = services.filter(\.isActive)
        let previewed = active.first { $0.id == serviceID } ?? defaultService(in: active)
        let duration = previewed?.durationMinutes ?? fallbackMinutes
        let sample = sampleVisit(on: day, settings: settings, services: active, calendar: calendar)

        var sampleSettings = settings
        sampleSettings.minNoticeHours = 0
        sampleSettings.daysOff = []
        sampleSettings.maxDaysAhead = max(settings.maxDaysAhead, 1)
        let plan = FreeSlotsCalculator.plan(for: FreeSlotsRequest(
            day: day, durationMinutes: max(duration, 1), now: day, settings: sampleSettings,
            appointments: sample.map { [$0.interval] } ?? [],
            stepMinutes: settings.effectiveSlotStep, timing: previewed?.visitTiming ?? .noExtraTime,
            compact: settings.keepsDayCompact,
            shortestOfferMinutes: active.isEmpty
                ? duration : AvailabilitySettings.shortestOfferMinutes(of: active)
        ))
        return SlotPreview(
            day: day, serviceName: previewed?.name, durationMinutes: duration, sampleVisit: sample?.visit,
            shownFirst: plan.recommended, alsoBookable: plan.more
        )
    }

    /// Her longest active service: the one whose times move most with the settings.
    static func defaultService(in services: [Service]) -> Service? {
        services.max { lhs, rhs in
            lhs.durationMinutes == rhs.durationMinutes ? lhs.position > rhs.position
                : lhs.durationMinutes < rhs.durationMinutes
        }
    }

    // MARK: - Private

    /// The first day after `now`'s day (within `lookaheadDays`) with working hours.
    private static func nextWorkingDay(after now: Date, settings: AvailabilitySettings, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        for offset in 1...lookaheadDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            if settings.weekly.contains(where: { $0.weekday == weekday && $0.endMinutes > $0.startMinutes }) {
                return day
            }
        }
        return nil
    }

    /// Her shortest service, booked an hour after the first opening of the day, when it fits in that stretch.
    private static func sampleVisit(
        on day: Date, settings: AvailabilitySettings, services: [Service], calendar: Calendar
    ) -> (visit: SlotPreview.SampleVisit, interval: TimedInterval)? {
        guard let shortest = services.min(by: { $0.durationMinutes < $1.durationMinutes }) else { return nil }
        let weekday = calendar.component(.weekday, from: day)
        guard let first = settings.weekly.filter({ $0.weekday == weekday }).min(by: {
            $0.startMinutes < $1.startMinutes
        }) else { return nil }
        let timing = shortest.visitTiming
        let startMinutes = first.startMinutes + sampleVisitOffsetMinutes
        guard startMinutes + shortest.durationMinutes + max(timing.cleanupMinutes, 0) <= first.endMinutes,
              let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
              let interval = FreeSlotsCalculator.interval(
                  startMinutes: startMinutes, endMinutes: startMinutes + shortest.durationMinutes,
                  dayStart: day, nextDayStart: nextDay, calendar: calendar
              ) else { return nil }
        let visit = SlotPreview.SampleVisit(
            serviceName: shortest.name, start: interval.start, minutes: shortest.durationMinutes
        )
        return (visit, TimedInterval(interval, timing: timing))
    }
}
