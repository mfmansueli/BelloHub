//
//  CalendarTestFactories.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// A time zone and the day it changes its clocks (or, for the zones that stopped, a day when nothing happens), with
/// the real hours between 00:00 and 06:00 local on that day. Used by every calendar rule that must be right on a
/// daylight-saving change day. All four transition days of 2026 are Sundays (weekday 1).
struct ZoneDay: Sendable, CustomTestStringConvertible {
    let zone: String
    let date: String
    /// 23 (spring forward), 24 or 25 (fall back).
    let dayHours: Int
    /// Real hours from 00:00 to 06:00 local.
    let windowHours: Int

    var testDescription: String { "\(zone) \(date)" }

    var calendar: Calendar { TestClock.calendar(zone) }

    var midnight: Date { TestClock.date("\(date) 00:00", zone: zone) }

    /// A Sunday 00:00 to 06:00 working week, one hour per slot.
    var overnightSettings: AvailabilitySettings {
        AvailabilitySettings(
            weekly: [AvailabilityRule(weekday: 1, startMinutes: 0, endMinutes: 360)], breaks: [], daysOff: [],
            bufferMinutes: 0, minNoticeHours: 0, maxDaysAhead: 3_650, timeZoneID: zone
        )
    }

    static let all: [ZoneDay] = [
        ZoneDay(zone: "Europe/Lisbon", date: "2026-03-29", dayHours: 23, windowHours: 5),
        ZoneDay(zone: "Europe/Lisbon", date: "2026-10-25", dayHours: 25, windowHours: 7),
        ZoneDay(zone: "Europe/Madrid", date: "2026-03-29", dayHours: 23, windowHours: 5),
        ZoneDay(zone: "Europe/Madrid", date: "2026-10-25", dayHours: 25, windowHours: 7),
        ZoneDay(zone: "America/New_York", date: "2026-03-08", dayHours: 23, windowHours: 5),
        ZoneDay(zone: "America/New_York", date: "2026-11-01", dayHours: 25, windowHours: 7),
        // No daylight-saving time since 2022 (Mexico) and 2019 (Brazil): the same days are plain 24-hour days.
        ZoneDay(zone: "America/Mexico_City", date: "2026-03-29", dayHours: 24, windowHours: 6),
        ZoneDay(zone: "America/Mexico_City", date: "2026-10-25", dayHours: 24, windowHours: 6),
        ZoneDay(zone: "America/Sao_Paulo", date: "2026-03-29", dayHours: 24, windowHours: 6),
        ZoneDay(zone: "America/Sao_Paulo", date: "2026-10-25", dayHours: 24, windowHours: 6)
    ]
}

/// An appointment from `start` for `minutes`, held (booked) by default.
func makeVisit(
    id: UUID = UUID(), clientID: UUID = UUID(), start: Date, minutes: Int = 60,
    status: AppointmentStatus = .booked, serviceName: String = "Glow Facial"
) -> Appointment {
    Appointment(
        id: id, clientID: clientID, serviceName: serviceName, startsAt: start,
        endsAt: start.addingTimeInterval(TimeInterval(minutes * 60)), status: status, createdAt: TestClock.days(-30)
    )
}

func makeBlock(start: Date, minutes: Int = 120, reason: String? = nil) -> TimeBlock {
    TimeBlock(id: UUID(), startsAt: start, endsAt: start.addingTimeInterval(TimeInterval(minutes * 60)), reason: reason)
}

/// Fri 2026-10-02 at `time` in São Paulo ("10:00"). Thursday 2026-10-01 is `TestClock.now`'s day.
func friday(_ time: String) -> Date {
    TestClock.date("2026-10-02 \(time)")
}

@MainActor
struct CalendarWorld {
    /// The protocol, as the ViewModels see it: its calls can throw, so the tests mark them `try` like the code does.
    let repository: any ClientRecordRepository
    /// The same store, for a fake that wraps it.
    let memory: InMemoryClientRecordRepository
    let vault: VaultService
    let profile: ProfileService
    let appointments: AppointmentService
    let timeBlocks: TimeBlockService
    let bookingSetup: BookingSetupService
    let ana: Client
    let beatriz: Client
    let glow: Service
    let deep: Service

    static func make(availability: AvailabilitySettings = makeAvailability()) async throws -> CalendarWorld {
        let memory = InMemoryClientRecordRepository(clock: { TestClock.now })
        let repository: any ClientRecordRepository = memory
        let vault = VaultService(repository: repository)
        let profile = ProfileService(vault: vault)
        try await repository.save(makeHealthProfile())
        await profile.load()
        let ana = Client(name: "Ana Costa", phoneE164: "+5511981234410", createdAt: TestClock.days(-200))
        let beatriz = Client(name: "Beatriz Lima", createdAt: TestClock.days(-100))
        _ = try await repository.save(ana)
        _ = try await repository.save(beatriz)
        let glow = Service(name: "Glow Facial", durationMinutes: 60, followUpWeeks: 4)
        let deep = Service(name: "Deep Cleansing", durationMinutes: 75, position: 1)
        try await repository.save(glow)
        try await repository.save(deep)
        try await repository.save(availability)
        let bookingSetup = BookingSetupService(vault: vault, now: { TestClock.now })
        try await bookingSetup.load(timeZoneID: availability.timeZoneID)
        return CalendarWorld(
            repository: repository, memory: memory, vault: vault, profile: profile,
            appointments: AppointmentService(vault: vault), timeBlocks: TimeBlockService(vault: vault),
            bookingSetup: bookingSetup, ana: ana, beatriz: beatriz, glow: glow, deep: deep
        )
    }
}
