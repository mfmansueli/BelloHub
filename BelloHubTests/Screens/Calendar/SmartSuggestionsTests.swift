//
//  SmartSuggestionsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Her own calendar's suggestions and warnings with the smart slots of D56: the same engine as the booking page, with
/// each visit's extra and processing time taken from its service. Friday 2026-10-02: 09:00 to 19:00, lunch 12:30 to
/// 13:30, a 15-minute buffer.
@Suite("Calendar smart suggestions")
struct SmartSuggestionsTests {
    private let colour = Service(name: "Colour", durationMinutes: 90,
                                 timing: VisitTiming(processingStartMinutes: 30, processingMinutes: 45))
    private let brows = Service(name: "Brows", durationMinutes: 45)
    private var friday: Date { TestClock.date("2026-10-02 00:00") }

    private func at(_ clock: String) -> Date { TestClock.date("2026-10-02 \(clock)") }

    /// Colour booked 10:00 to 11:30; she is free from 10:30 to 11:15 while it develops.
    private var colourVisit: Appointment {
        var visit = makeVisit(start: at("10:00"), minutes: 90, serviceName: "Colour")
        visit.serviceID = colour.id
        return visit
    }

    private func request(
        minutes: Int = 45, settings: AvailabilitySettings = makeAvailability(), services: [Service]? = nil,
        timing: VisitTiming = .noExtraTime
    ) -> OpenTimes.Request {
        OpenTimes.Request(
            durationMinutes: minutes, settings: settings, appointments: [colourVisit], blocks: [], now: TestClock.now,
            services: services ?? [colour, brows], timing: timing
        )
    }

    @Test("A short visit is suggested inside another visit's processing time")
    func insideProcessing() {
        let plan = OpenTimes.plan(on: friday, request())
        #expect(plan.recommended.contains(at("10:30")))
        #expect(!plan.all.contains(at("10:45")), "10:45 to 11:30 runs past the processing time")
        let unaware = OpenTimes.plan(on: friday, request(services: []))
        #expect(!unaware.all.contains(at("10:30")), "without the service, the colour is one solid visit")
    }

    @Test("With the day kept compact, a start that leaves a gap nobody can book waits behind Show all times")
    func compactDay() {
        let plan = OpenTimes.plan(on: friday, request())
        #expect(plan.recommended.contains(at("13:30")))
        #expect(plan.more.contains(at("13:45")), "13:30 to 13:45 is too short for her shortest offer")
        var loose = makeAvailability()
        loose.compactDay = false
        let all = OpenTimes.plan(on: friday, request(settings: loose))
        #expect(all.recommended == all.all && all.more.isEmpty)
    }

    @Test("Her slot interval from Booking settings is the grid; \"match the service\" steps by the visit and buffer")
    func slotInterval() {
        var settings = makeAvailability()
        settings.slotStepMinutes = FreeSlotsRequest.matchServiceStep
        let plan = OpenTimes.plan(on: friday, request(settings: settings))
        #expect(plan.all.contains(at("14:00")), "09:00 + 5 x (45 minutes + the 15-minute buffer)")
        #expect(plan.all.contains(at("13:30")), "anchored right after lunch")
        #expect(!plan.all.contains(at("14:15")))
        #expect(OpenTimes.plan(on: friday, request()).all.contains(at("14:15")), "the default grid is 15 minutes")
    }

    @Test("A visit inside the processing time is not an overlap; outside it, it is")
    func warningsRespectProcessing() {
        func overlaps(at start: String, services: [Service]) -> Bool {
            SchedulingWarningEngine.warnings(for: SchedulingWarningInput(
                interval: DateInterval(start: at(start), duration: 45 * 60), settings: makeAvailability(),
                appointments: [colourVisit], blocks: [], service: brows, clientID: nil, now: TestClock.now,
                services: services
            )).contains { $0.isScheduleConflict }
        }
        #expect(!overlaps(at: "10:30", services: [colour, brows]))
        #expect(overlaps(at: "10:45", services: [colour, brows]))
        #expect(overlaps(at: "10:30", services: []))
    }

    @Test("Prep and clean-up bring a neighbour inside the buffer or into an overlap")
    func warningsRespectExtraTime() {
        let glow = Service(name: "Glow", durationMinutes: 60, timing: VisitTiming(prepMinutes: 10, cleanupMinutes: 20))
        var before = makeVisit(start: at("09:00"))
        before.serviceID = glow.id
        func warnings(start: String, service: Service) -> [SchedulingWarning] {
            SchedulingWarningEngine.warnings(for: SchedulingWarningInput(
                interval: DateInterval(start: at(start), duration: 60 * 60), settings: makeAvailability(),
                appointments: [before], blocks: [], service: service, clientID: nil, now: TestClock.now,
                services: [glow]
            ))
        }
        #expect(warnings(start: "10:10", service: brows).contains(.overlap(with: before.id)),
                "its clean-up runs to 10:20")
        #expect(warnings(start: "10:30", service: brows).contains(.buffer(minutes: 15, neighbour: before.id)))
        #expect(!warnings(start: "10:30", service: brows).contains(.overlap(with: before.id)))
        #expect(!warnings(start: "10:35", service: brows).contains { $0.isScheduleConflict })
        #expect(warnings(start: "10:40", service: glow).contains(.buffer(minutes: 15, neighbour: before.id)),
                "its own prep starts at 10:30")
    }
}
