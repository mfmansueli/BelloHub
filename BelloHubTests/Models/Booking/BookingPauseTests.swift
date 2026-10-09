//
//  BookingPauseTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BookingPause")
struct BookingPauseTests {
    private let zone = TestClock.saoPaulo
    /// Thursday 2026-10-01, 12:00 in São Paulo.
    private let now = TestClock.now

    private func day(_ text: String) -> Date { TestClock.date("\(text) 00:00") }

    @Test("An open page is accepting")
    func open() {
        #expect(BookingPause.state(of: .standard, now: now, timeZone: zone) == .accepting)
    }

    @Test("A pause with no date lasts until she opens bookings again")
    func openEnded() {
        let paused = BookingPause.pausing(.standard, until: nil, now: now, timeZone: zone)
        #expect(!paused.acceptingBookings && paused.pausedUntil == nil)
        #expect(BookingPause.state(of: paused, now: now.addingTimeInterval(86_400 * 400), timeZone: zone)
            == .paused(until: nil))
    }

    @Test("A pause with a return date ends on the morning of that date, in the business zone")
    func returnDate() {
        let paused = BookingPause.pausing(.standard, until: day("2026-10-20"), now: now, timeZone: zone)
        #expect(paused.pausedUntil == day("2026-10-20"))
        #expect(BookingPause.state(of: paused, now: TestClock.date("2026-10-19 23:59"), timeZone: zone)
            == .paused(until: day("2026-10-20")))
        #expect(BookingPause.state(of: paused, now: TestClock.date("2026-10-20 00:00"), timeZone: zone) == .accepting)
        #expect(BookingPause.state(of: paused, now: TestClock.date("2026-10-20 09:00"), timeZone: zone) == .accepting)
    }

    @Test("A return date picked at noon is stored as the start of that day")
    func returnDateIsStartOfDay() {
        let paused = BookingPause.pausing(.standard, until: TestClock.date("2026-10-20 15:30"), now: now,
            timeZone: zone)
        #expect(paused.pausedUntil == day("2026-10-20"))
    }

    @Test("A return date today or in the past is dropped, not saved as a pause that is already over")
    func pastReturnDate() {
        for text in ["2026-10-01", "2026-09-15"] {
            let paused = BookingPause.pausing(.standard, until: TestClock.date("\(text) 10:00"), now: now,
                timeZone: zone)
            #expect(!paused.acceptingBookings && paused.pausedUntil == nil, "\(text)")
        }
    }

    @Test("The earliest return date is tomorrow")
    func earliest() {
        #expect(BookingPause.earliestReturnDate(now: now, timeZone: zone) == day("2026-10-02"))
        // 23:30 in São Paulo is already the next day in UTC: the business day decides.
        let lateNight = TestClock.date("2026-10-01 23:30")
        #expect(BookingPause.earliestReturnDate(now: lateNight, timeZone: zone) == day("2026-10-02"))
    }

    @Test("Resuming opens the page and forgets the date")
    func resume() {
        let paused = BookingPause.pausing(.standard, until: day("2026-10-20"), now: now, timeZone: zone)
        let open = BookingPause.resuming(paused)
        #expect(open.acceptingBookings && open.pausedUntil == nil)
    }

    @Test("Resuming keeps the other switches")
    func resumeKeepsSwitches() {
        var settings = BookingPageSettings.standard
        settings.confirmNewClients = true
        settings.maxGuests = 2
        let open = BookingPause.resuming(BookingPause.pausing(settings, until: nil, now: now, timeZone: zone))
        #expect(open.confirmNewClients && open.maxGuests == 2)
    }

    @Test("An expired pause is stored as an open page")
    func normalizedExpired() {
        var settings = BookingPageSettings.standard
        settings.acceptingBookings = false
        settings.pausedUntil = day("2026-09-20")
        #expect(BookingPause.normalized(settings, now: now, timeZone: zone) == BookingPause.resuming(settings))
    }

    @Test("A running pause and an open page are stored as they are")
    func normalizedUnchanged() {
        let running = BookingPause.pausing(.standard, until: day("2026-10-20"), now: now, timeZone: zone)
        #expect(BookingPause.normalized(running, now: now, timeZone: zone) == running)
        #expect(BookingPause.normalized(.standard, now: now, timeZone: zone) == .standard)
    }

    @Test("The day of the return date follows the business zone, not the phone's")
    func zones() {
        let lisbon = TimeZone(identifier: "Europe/Lisbon") ?? .gmt
        let returnDay = TestClock.date("2026-10-20 00:00", zone: "Europe/Lisbon")
        var settings = BookingPageSettings.standard
        settings.acceptingBookings = false
        settings.pausedUntil = returnDay
        let justBefore = returnDay.addingTimeInterval(-60)
        #expect(BookingPause.state(of: settings, now: justBefore, timeZone: lisbon) == .paused(until: returnDay))
        #expect(BookingPause.state(of: settings, now: returnDay, timeZone: lisbon) == .accepting)
    }
}
