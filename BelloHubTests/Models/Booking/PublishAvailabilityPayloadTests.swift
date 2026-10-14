//
//  PublishAvailabilityPayloadTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PublishPayloads: availability and the contract")
struct PublishAvailabilityPayloadTests {
    private let now = TestClock.now

    private func availability(_ inputs: PublishInputs = makePublishInputs()) -> PublishAvailabilityRequest {
        PublishPayloads.availability(inputs, now: now)
    }

    private func json(_ value: some Encodable) throws -> Data {
        try CallableJSON.encoder.encode(value)
    }

    // MARK: - Availability

    @Test("Hours, breaks, buffer, notice and window come from her availability")
    func hours() {
        let sent = availability()
        #expect(sent.timeZoneID == "America/Sao_Paulo")
        #expect(sent.weekly.map(\.weekday) == [3, 4, 5, 6, 7])
        #expect(sent.weekly.first?.startMinutes == 540 && sent.weekly.first?.endMinutes == 1140)
        #expect(sent.breaks == [.init(weekday: nil, startMinutes: 750, endMinutes: 810)])
        #expect(sent.bufferMinutes == 15 && sent.minNoticeHours == 2 && sent.maxDaysAhead == 60)
    }

    @Test("The no-show rule travels with the availability")
    func noShow() {
        var inputs = makePublishInputs()
        inputs.setup.noShow = NoShowPolicy(
            isOn: true, limit: 2, action: .pauseOnline, lateCancelCounts: true, countingMonths: 6
        )
        let sent = availability(inputs).noShow
        #expect(sent == .init(isOn: true, limit: 2, action: "pauseOnline", lateCancelCounts: true, countingMonths: 6))
    }

    @Test("Nonsense in the stored hours never reaches the server")
    func filtersInvalidHours() {
        var inputs = makePublishInputs()
        inputs.availability.weekly = [
            AvailabilityRule(weekday: 0, startMinutes: 60, endMinutes: 120),
            AvailabilityRule(weekday: 2, startMinutes: 600, endMinutes: 600),
            AvailabilityRule(weekday: 2, startMinutes: -5, endMinutes: 100),
            AvailabilityRule(weekday: 2, startMinutes: 600, endMinutes: 1500),
            AvailabilityRule(weekday: 2, startMinutes: 600, endMinutes: 700)
        ]
        inputs.availability.bufferMinutes = 500
        inputs.availability.minNoticeHours = 9_999
        inputs.availability.maxDaysAhead = 0
        let sent = availability(inputs)
        #expect(sent.weekly == [.init(weekday: 2, startMinutes: 600, endMinutes: 700)])
        #expect(sent.bufferMinutes == 120 && sent.minNoticeHours == 336 && sent.maxDaysAhead == 1)
    }

    @Test("Days off are local dates in her time zone and finished ones are dropped")
    func daysOff() {
        var inputs = makePublishInputs()
        let calendar = TestClock.calendar()
        func day(_ offset: Int) -> Date { calendar.startOfDay(for: TestClock.days(offset)) }
        inputs.availability.daysOff = [
            DayOff(id: UUID(), startDate: day(-10), endDate: day(-8), kind: .vacation),
            DayOff(id: UUID(), startDate: day(5), endDate: day(7), kind: .vacation),
            DayOff(id: UUID(), startDate: day(-1), endDate: day(0), kind: .vacation)
        ]
        #expect(availability(inputs).daysOff == [
            .init(startDate: "2026-09-30", endDate: "2026-10-01"),
            .init(startDate: "2026-10-06", endDate: "2026-10-08")
        ])
    }

    @Test("A local date uses the business time zone and plain digits")
    func localDates() {
        // 23:30 in São Paulo is already the next day in UTC.
        let late = TestClock.date("2026-10-01 23:30")
        #expect(PublishPayloads.localDate(late, timeZone: TestClock.saoPaulo) == "2026-10-01")
        #expect(PublishPayloads.localDate(late, timeZone: TimeZone(secondsFromGMT: 0) ?? .gmt) == "2026-10-02")
    }

    // MARK: - Busy

    @Test("Busy is her manual visits and her blocks, and never a visit that came from the link")
    func busyRules() {
        let appointments = [
            makeVisit(hours: 1),
            makeVisit(hours: 3, origin: .bookingLink),
            makeVisit(hours: 4, bookingID: "abc123"),
            makeVisit(hours: 5, status: .cancelled),
            makeVisit(hours: 6, status: .completed),
            makeVisit(hours: 7, status: .noShow),
            makeVisit(hours: 8, status: .confirmed),
            makeVisit(hours: -5)
        ]
        let sent = availability(makePublishInputs(appointments: appointments, blocks: [makeBlock(hours: 2)])).busy
        #expect(sent.map(\.kind) == ["appointment", "block", "appointment"])
        #expect(sent.map(\.startsAt) == [
            now.addingTimeInterval(3_600), now.addingTimeInterval(7_200), now.addingTimeInterval(8 * 3_600)
        ])
    }

    @Test("A manual visit keeps its original timing after the service catalog changes")
    func busyUsesVisitSnapshot() {
        var visit = makeVisit(hours: 1)
        visit.serviceTiming = VisitTiming(prepMinutes: 10, cleanupMinutes: 5,
                                          processingStartMinutes: 20, processingMinutes: 15)
        let sent = availability(makePublishInputs(appointments: [visit])).busy
        #expect(sent.first?.prepMinutes == 10)
        #expect(sent.first?.cleanupMinutes == 5)
        #expect(sent.first?.processingStartMinutes == 20)
        #expect(sent.first?.processingMinutes == 15)
    }

    @Test("A visit still running counts, one that ended does not")
    func busyBoundaries() {
        let running = makeVisit(hours: -0.5)
        let sent = availability(makePublishInputs(appointments: [running, makeVisit(hours: -2)])).busy
        #expect(sent.count == 1 && sent[0].startsAt == running.startsAt)
    }

    @Test("Busy is capped at 600 stretches, nearest first")
    func busyCap() {
        let many = (1...700).map { makeVisit(hours: Double($0)) }
        let sent = availability(makePublishInputs(appointments: many)).busy
        #expect(sent.count == PublishPayloads.busyLimit)
        #expect(sent.first?.startsAt == many.first?.startsAt)
    }

    @Test("No name, service or reason leaves the phone in the availability")
    func privacy() throws {
        let inputs = makePublishInputs(appointments: [makeVisit(hours: 1)], blocks: [makeBlock(hours: 2)])
        let text = String(bytes: try json(availability(inputs)), encoding: .utf8) ?? ""
        for secret in ["Secret treatment", "private note", "Dentist"] { #expect(!text.contains(secret)) }
    }

    // MARK: - Determinism and the contract

    @Test("The same inputs and time give equal requests, byte for byte")
    func deterministic() throws {
        let inputs = makePublishInputs(appointments: [makeVisit(hours: 1)])
        #expect(PublishPayloads.profile(inputs, now: now) == PublishPayloads.profile(inputs, now: now))
        let first = try json(availability(inputs))
        let second = try json(availability(inputs))
        #expect(first == second)
    }

    @Test("A change to one half does not change the other")
    func independentHalves() {
        let base = makePublishInputs()
        var edited = base
        edited.availability.bufferMinutes = 30
        #expect(PublishPayloads.profile(base, now: now) == PublishPayloads.profile(edited, now: now))
        #expect(PublishPayloads.availability(base, now: now) != PublishPayloads.availability(edited, now: now))
    }

    @Test("The page and the availability satisfy the backend's published schemas")
    func contract() throws {
        var inputs = makePublishInputs(
            appointments: [makeVisit(hours: 1), makeVisit(hours: 2)], blocks: [makeBlock(hours: 2)]
        )
        inputs.profile.bookingLocaleIDs = ["en", "ar", "hi", "de", "fr"]
        inputs.credentials.append(Credential(kind: .registration, title: "", registrationNumber: "CRBM 1234"))
        inputs.setup.noShow = NoShowPolicy(
            isOn: true, limit: 2, action: .pauseOnline, lateCancelCounts: true, countingMonths: 6
        )
        let calendar = TestClock.calendar()
        inputs.availability.daysOff = [DayOff(
            id: UUID(), startDate: calendar.startOfDay(for: TestClock.days(3)),
            endDate: calendar.startOfDay(for: TestClock.days(4)), kind: .vacation
        )]
        let profile = try ServerContract.violations(
            of: json(PublishPayloads.profile(inputs, now: now)), for: "publishProfile"
        )
        let hours = try ServerContract.violations(
            of: json(PublishPayloads.availability(inputs, now: now)), for: "publishAvailability"
        )
        for problem in profile + hours { Issue.record(Comment(rawValue: problem)) }
    }

    @Test("A paused page satisfies the schema too")
    func contractPaused() throws {
        let paused = BookingPause.pausing(.standard, until: TestClock.days(5), now: now, timeZone: TestClock.saoPaulo)
        let body = try json(PublishPayloads.profile(makePublishInputs(page: paused), now: now))
        for problem in try ServerContract.violations(of: body, for: "publishProfile") {
            Issue.record(Comment(rawValue: problem))
        }
    }

    @Test("The contract checker really rejects a bad request")
    func checkerRejects() throws {
        var request = PublishPayloads.profile(makePublishInputs(), now: now)
        request.profile.services = []
        request.profile.inboxKey = InboxPublicKey(keyId: "short", pub: "short")
        let problems = try ServerContract.violations(of: json(request), for: "publishProfile")
        #expect(problems.count >= 3)
    }

    @Test("Every function the app calls is in the contract")
    func functionsExist() throws {
        let names = try ServerContract.functionNames()
        let used = [
            "ensureAccount", "isSlugAvailable", "claimSlug", "publishProfile", "publishAvailability",
            "updateInboxKey", "setOnlineBookingStopped"
        ]
        for name in used { #expect(names.contains(name), "\(name)") }
    }
}
