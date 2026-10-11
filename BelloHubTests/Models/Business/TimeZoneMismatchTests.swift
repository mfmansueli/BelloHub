//
//  TimeZoneMismatchTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("TimeZoneMismatch")
struct TimeZoneMismatchTests {
    private func utc(_ text: String) -> Date { TestClock.date(text, zone: "UTC") }

    private func minutes(business: String, phone: String, at now: Date = TestClock.now) -> Int? {
        TimeZoneMismatch.check(businessZoneID: business, phoneZoneID: phone, now: now)?.phoneAheadMinutes
    }

    // MARK: - Same hour: no notice

    @Test("The same zone, or a zone showing the same hour right now, never notifies")
    func sameHour() {
        #expect(minutes(business: "America/Sao_Paulo", phone: "America/Sao_Paulo") == nil)
        // Different ids with the same offset, in summer and in winter.
        #expect(minutes(business: "Europe/Paris", phone: "Europe/Rome", at: utc("2026-07-01 12:00")) == nil)
        #expect(minutes(business: "Europe/Paris", phone: "Europe/Rome", at: utc("2026-12-01 12:00")) == nil)
        #expect(minutes(business: "America/Sao_Paulo", phone: "America/Argentina/Buenos_Aires") == nil)
        // An alias of the same zone.
        #expect(minutes(business: "Asia/Kolkata", phone: "Asia/Calcutta") == nil)
        #expect(minutes(business: "Europe/Lisbon", phone: "Europe/London", at: utc("2026-10-25 01:00")) == nil)
    }

    @Test("A zone Foundation does not know is never named")
    func unknownZone() {
        #expect(minutes(business: "America/Sao_Paulo", phone: "Mars/Olympus_Mons") == nil)
        #expect(minutes(business: "Nowhere/Town", phone: "Europe/Rome") == nil)
    }

    // MARK: - Different hour

    @Test("The owners' case: an iPhone in Rome is 5 hours ahead of a business in São Paulo in October")
    func romeAheadOfSaoPaulo() throws {
        let mismatch = try #require(TimeZoneMismatch.check(
            businessZoneID: "America/Sao_Paulo", phoneZoneID: "Europe/Rome", now: TestClock.now
        ))
        #expect(mismatch.phoneAheadMinutes == 300)
        #expect(mismatch.isPhoneAhead)
        #expect(mismatch.differenceMinutes == 300)
        #expect(mismatch.pair == .init(businessZoneID: "America/Sao_Paulo", phoneZoneID: "Europe/Rome"))
    }

    @Test("An iPhone west of the business is behind it")
    func behind() throws {
        let mismatch = try #require(TimeZoneMismatch.check(
            businessZoneID: "America/Sao_Paulo", phoneZoneID: "Pacific/Honolulu", now: TestClock.now
        ))
        #expect(mismatch.phoneAheadMinutes == -420)
        #expect(!mismatch.isPhoneAhead)
        #expect(mismatch.differenceMinutes == 420)
    }

    @Test("Half-hour and quarter-hour zones keep their minutes")
    func partialHours() {
        #expect(minutes(business: "America/Sao_Paulo", phone: "Asia/Kolkata") == 510)
        #expect(minutes(business: "Asia/Kolkata", phone: "Asia/Kathmandu") == 15)
        #expect(minutes(business: "Australia/Sydney", phone: "Australia/Adelaide") == -30)
        #expect(minutes(business: "America/St_Johns", phone: "America/Sao_Paulo") == -30)
    }

    // MARK: - Daylight saving boundaries

    @Test("Europe leaves summer time on 25 October 2026 at 01:00 UTC: Rome goes from 5 to 4 hours ahead of São Paulo")
    func europeanFallBack() {
        #expect(minutes(business: "America/Sao_Paulo", phone: "Europe/Rome", at: utc("2026-10-25 00:59")) == 300)
        #expect(minutes(business: "America/Sao_Paulo", phone: "Europe/Rome", at: utc("2026-10-25 01:00")) == 240)
    }

    @Test("New York leaves summer time on 1 November 2026 at 06:00 UTC: from 1 to 2 hours behind São Paulo")
    func americanFallBack() {
        #expect(minutes(business: "America/Sao_Paulo", phone: "America/New_York", at: utc("2026-11-01 05:59")) == -60)
        #expect(minutes(business: "America/Sao_Paulo", phone: "America/New_York", at: utc("2026-11-01 06:00")) == -120)
    }

    @Test("Zones that agree in winter and not in summer are reported only while they differ")
    func agreeOnlyInWinter() {
        #expect(minutes(business: "Africa/Lagos", phone: "Europe/Rome", at: utc("2026-01-15 12:00")) == nil)
        #expect(minutes(business: "Africa/Lagos", phone: "Europe/Rome", at: utc("2026-07-15 12:00")) == 60)
        // The day Europe springs forward: 29 March 2026 at 01:00 UTC.
        #expect(minutes(business: "Africa/Lagos", phone: "Europe/Rome", at: utc("2026-03-29 00:59")) == nil)
        #expect(minutes(business: "Africa/Lagos", phone: "Europe/Rome", at: utc("2026-03-29 01:00")) == 60)
    }

    // MARK: - Keep it

    @Test("A kept pair hides the notice until either zone changes")
    func keptPair() {
        let kept = TimeZoneMismatch.Pair(businessZoneID: "America/Sao_Paulo", phoneZoneID: "Europe/Rome")
        func notice(_ business: String, _ phone: String) -> TimeZoneMismatch? {
            TimeZoneMismatch.notice(businessZoneID: business, phoneZoneID: phone, kept: kept, now: TestClock.now)
        }
        #expect(notice("America/Sao_Paulo", "Europe/Rome") == nil)
        #expect(notice("America/Sao_Paulo", "Asia/Tokyo") != nil, "she travelled on")
        #expect(notice("America/Manaus", "Europe/Rome") != nil, "the business zone changed")
        #expect(TimeZoneMismatch.notice(
            businessZoneID: "America/Sao_Paulo", phoneZoneID: "Europe/Rome", kept: nil, now: TestClock.now
        ) != nil)
    }

    // MARK: - Region note

    @Test("The region note appears only when the iPhone's zone belongs to another preset's country")
    func regionNote() throws {
        let regions = try RegionCatalog.loadBundled()
        #expect(TimeZoneMismatch.isInAnotherRegion(phoneZoneID: "Europe/Rome", businessRegionCode: "BR", regions: regions))
        #expect(TimeZoneMismatch.isInAnotherRegion(phoneZoneID: "Europe/Rome", businessRegionCode: "br", regions: regions))
        #expect(!TimeZoneMismatch.isInAnotherRegion(
            phoneZoneID: "America/Manaus", businessRegionCode: "BR", regions: regions
        ))
        #expect(!TimeZoneMismatch.isInAnotherRegion(phoneZoneID: "Asia/Tokyo", businessRegionCode: "BR", regions: regions))
    }
}
