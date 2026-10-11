//
//  TestFactories.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// Fixed dates and `makeX()` factories. Every test passes `now` explicitly; nothing reads the clock.
enum TestClock {
    static let saoPaulo = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt

    /// Thursday 2026-10-01, 12:00 in São Paulo (the prototype's "today" is Wednesday Sep 30; a Thursday keeps
    /// weekday arithmetic obvious in the tests).
    static let now = date("2026-10-01 12:00")

    static func calendar(_ zoneID: String = "America/Sao_Paulo") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zoneID) ?? .gmt
        calendar.firstWeekday = 1
        return calendar
    }

    /// `"2026-10-01 15:30"` read as local time in `zoneID`.
    static func date(_ text: String, zone zoneID: String = "America/Sao_Paulo") -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: zoneID)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let date = formatter.date(from: text) else {
            preconditionFailure("bad test date \(text)")
        }
        return date
    }

    /// A date `days` days before or after `now`, same time of day.
    static func days(_ days: Int, from base: Date = now) -> Date {
        calendar().date(byAdding: .day, value: days, to: base) ?? base
    }
}

func makeClient(
    id: UUID = UUID(),
    name: String = "Ana Costa",
    isArchived: Bool = false,
    remindersEnabled: Bool = true,
    birthday: Birthday? = nil,
    noShowCountResetAt: Date? = nil
) -> Client {
    Client(
        id: id, name: name, birthday: birthday, isArchived: isArchived, remindersEnabled: remindersEnabled,
        noShowCountResetAt: noShowCountResetAt, createdAt: TestClock.days(-200)
    )
}

func makeService(
    id: UUID = UUID(), name: String = "Glow Facial", minutes: Int = 60, followUpWeeks: Int? = 4
) -> Service {
    Service(id: id, name: name, durationMinutes: minutes, followUpWeeks: followUpWeeks)
}

/// An appointment `daysFromNow` days from `TestClock.now`, at `hour` local time.
func makeAppointment(
    clientID: UUID,
    daysFromNow: Int,
    hour: Int = 11,
    minutes: Int = 60,
    status: AppointmentStatus = .completed,
    serviceID: UUID? = nil,
    serviceName: String = "Glow Facial",
    cancelledBy: CancelledBy? = nil,
    isLate: Bool = false,
    forgiven: Bool = false,
    sessionPlanID: UUID? = nil
) -> Appointment {
    let calendar = TestClock.calendar()
    let day = calendar.startOfDay(for: TestClock.days(daysFromNow))
    let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    return Appointment(
        clientID: clientID, serviceID: serviceID, serviceName: serviceName, startsAt: start,
        endsAt: start.addingTimeInterval(TimeInterval(minutes * 60)), status: status, cancelledBy: cancelledBy,
        isLateCancellation: isLate, sessionPlanID: sessionPlanID, noShowForgiven: forgiven, createdAt: start
    )
}

/// Maria's week from the prototype: Tuesday to Saturday, 09:00 to 19:00, lunch 12:30 to 13:30, 15 min buffer.
func makeAvailability(
    timeZoneID: String = "America/Sao_Paulo",
    weekdays: [Int] = [3, 4, 5, 6, 7],
    startMinutes: Int = 9 * 60,
    endMinutes: Int = 19 * 60,
    breaks: [BreakRule] = [BreakRule(weekday: nil, startMinutes: 750, endMinutes: 810, label: "Lunch")],
    daysOff: [DayOff] = [],
    bufferMinutes: Int = 15,
    minNoticeHours: Int = 2,
    maxDaysAhead: Int = 60
) -> AvailabilitySettings {
    AvailabilitySettings(
        weekly: weekdays.map { AvailabilityRule(weekday: $0, startMinutes: startMinutes, endMinutes: endMinutes) },
        breaks: breaks, daysOff: daysOff, bufferMinutes: bufferMinutes, minNoticeHours: minNoticeHours,
        maxDaysAhead: maxDaysAhead, timeZoneID: timeZoneID
    )
}
