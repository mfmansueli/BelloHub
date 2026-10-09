//
//  CalendarDayLayout.swift
//  BelloHub
//

import Foundation

/// Everything the day column draws, decided once and without a view: the visible stretch of the day, the hour marks,
/// where each visit sits (visits that overlap share the width in columns), her breaks and blocks, and whether she
/// works that day. The day view and the week grid both read it, so the two can never place a visit differently.
struct CalendarDayLayout: Equatable, Sendable {
    /// A visit placed in the day. `column` of `columnCount` is its share of the width.
    struct Visit: Equatable, Identifiable, Sendable {
        let id: UUID
        let interval: DateInterval
        let column: Int
        let columnCount: Int
    }

    /// A stretch drawn behind the visits.
    struct Band: Equatable, Identifiable, Sendable {
        let interval: DateInterval
        let kind: CalendarBandKind

        var id: String {
            switch kind {
            case .breakTime(let label): "break-\(label)-\(interval.start.timeIntervalSince1970)"
            case .blocked(let id): "block-\(id.uuidString)"
            }
        }
    }

    /// The start of the day in the business time zone.
    let day: Date
    /// The stretch of the day the column shows (whole hours).
    let window: DateInterval
    let hourMarks: [Date]
    let visits: [Visit]
    let bands: [Band]
    /// Her working stretches, to tell open hours from closed ones.
    let workingWindows: [DateInterval]
    /// A day off, or a weekday she does not work.
    let isClosed: Bool
    let dayOff: DayOff?

    /// How far down the column `date` is, from 0 (top) to 1 (bottom), clamped.
    func fraction(of date: Date) -> Double {
        guard window.duration > 0 else { return 0 }
        return min(max(date.timeIntervalSince(window.start) / window.duration, 0), 1)
    }

    /// The start time a tap at `fraction` of the column's height means, rounded down to `stepMinutes` of real time
    /// after the top of the column (which is a whole hour), so a tap always lands on a time she can book.
    func time(atFraction fraction: Double, stepMinutes: Int = 30) -> Date {
        let step = TimeInterval(max(stepMinutes, 1) * 60)
        let seconds = min(max(fraction, 0), 1) * window.duration
        let snapped = (seconds / step).rounded(.down) * step
        return window.start.addingTimeInterval(min(snapped, max(window.duration - step, 0)))
    }

    /// The visible stretch as wall-clock minutes (start and end), the same for every day of the week so the week
    /// grid lines up.
    struct VisibleMinutes: Equatable, Sendable {
        var start: Int
        var end: Int
    }

    static let defaultVisible = VisibleMinutes(start: 8 * 60, end: 20 * 60)
    static let minimumSpanMinutes = 4 * 60

    /// The hours to show: her earliest opening to her latest closing in the week, widened to hold every visit and
    /// block, in whole hours, never shorter than four.
    static func visibleMinutes(
        settings: AvailabilitySettings, appointments: [Appointment], blocks: [TimeBlock] = [], days: CalendarDays
    ) -> VisibleMinutes {
        var start = settings.weekly.map(\.startMinutes).min() ?? defaultVisible.start
        var end = settings.weekly.map(\.endMinutes).max() ?? defaultVisible.end
        let stretches = appointments.filter(isShown).map(\.interval) + blocks.map(\.interval)
        for stretch in stretches {
            start = min(start, minutes(of: stretch.start, days: days))
            // Anything that ends on a later day closes the column at midnight.
            end = days.isSameDay(stretch.start, stretch.end.addingTimeInterval(-1))
                ? max(end, minutes(of: stretch.end, days: days)) : 24 * 60
        }
        start = max(0, start / 60 * 60)
        end = min(24 * 60, (end + 59) / 60 * 60)
        if end - start < minimumSpanMinutes { end = min(24 * 60, start + minimumSpanMinutes) }
        if end - start < minimumSpanMinutes { start = max(0, end - minimumSpanMinutes) }
        return VisibleMinutes(start: start, end: end)
    }

    /// A cancelled visit leaves the calendar (it is in the client's history); a no-show stays, marked.
    static func isShown(_ appointment: Appointment) -> Bool {
        appointment.status != .cancelled
    }

    /// What every day of a week shares when it is laid out.
    struct Scale {
        let settings: AvailabilitySettings
        let visible: VisibleMinutes
        let days: CalendarDays
    }

    static func make(
        day: Date, appointments: [Appointment], blocks: [TimeBlock], scale: Scale
    ) -> CalendarDayLayout {
        let settings = scale.settings
        let visible = scale.visible
        let days = scale.days
        let dayStart = days.start(of: day)
        let dayInterval = days.interval(of: dayStart)
        let windowStart = days.date(on: dayStart, minutes: visible.start)
        let windowEnd = visible.end >= 24 * 60 ? dayInterval.end : days.date(on: dayStart, minutes: visible.end)
        let window = DateInterval(start: windowStart, end: max(windowEnd, windowStart.addingTimeInterval(3_600)))

        let shown = appointments.filter { isShown($0) && $0.interval.intersection(with: dayInterval) != nil }
        let placed = columns(for: shown.map { Stretch(id: $0.id, interval: $0.interval) })
        let breaks = FreeSlotsCalculator.breakWindows(on: dayStart, settings: settings).map {
            Band(interval: $0.interval, kind: .breakTime(label: $0.label))
        }
        let closed = blocks.filter { $0.interval.intersection(with: dayInterval) != nil }.map {
            Band(interval: $0.interval, kind: .blocked(id: $0.id))
        }
        let windows = FreeSlotsCalculator.workingWindows(on: dayStart, settings: settings)
        let calendar = days.calendar
        return CalendarDayLayout(
            day: dayStart, window: window, hourMarks: days.hourMarks(in: window), visits: placed,
            bands: (breaks + closed).sorted { $0.interval.start < $1.interval.start },
            workingWindows: windows, isClosed: windows.isEmpty,
            dayOff: FreeSlotsCalculator.dayOff(on: dayStart, settings: settings, calendar: calendar)
        )
    }

    // MARK: - Columns

    /// A stretch of time that needs a column.
    struct Stretch: Sendable {
        let id: UUID
        let interval: DateInterval
    }

    /// Gives each stretch a column so that stretches that overlap never share one. A cluster is a run of stretches
    /// that overlap one another in a chain; every stretch of a cluster is as wide as the cluster is deep. Stretches
    /// that only touch (one ends when the next starts) do not overlap.
    static func columns(for stretches: [Stretch]) -> [Visit] {
        let sorted = stretches.sorted {
            ($0.interval.start, $0.interval.end, $0.id.uuidString)
                < ($1.interval.start, $1.interval.end, $1.id.uuidString)
        }
        var result: [Visit] = []
        var cluster: [(stretch: Stretch, column: Int)] = []
        var columnEnds: [Date] = []
        var clusterEnd = Date.distantPast

        func flush() {
            let count = max(columnEnds.count, 1)
            result += cluster.map {
                Visit(id: $0.stretch.id, interval: $0.stretch.interval, column: $0.column, columnCount: count)
            }
            cluster = []
            columnEnds = []
        }

        for stretch in sorted {
            if stretch.interval.start >= clusterEnd { flush() }
            let column = columnEnds.firstIndex { $0 <= stretch.interval.start } ?? columnEnds.count
            if column == columnEnds.count { columnEnds.append(stretch.interval.end) } else {
                columnEnds[column] = stretch.interval.end
            }
            cluster.append((stretch, column))
            clusterEnd = cluster.map(\.stretch.interval.end).max() ?? stretch.interval.end
        }
        flush()
        return result
    }

    // MARK: - Private

    private static func minutes(of date: Date, days: CalendarDays) -> Int {
        let parts = days.calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
