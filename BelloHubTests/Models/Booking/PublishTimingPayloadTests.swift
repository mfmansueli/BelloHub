//
//  PublishTimingPayloadTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// What the page and the availability carry for the smart slots of D56: each service's extra and processing time, her
/// slot interval and "Keep my day compact", and the shape of her own visits. Plain services are sent as before.
@Suite("PublishPayloads: smart slots")
struct PublishTimingPayloadTests {
    private let now = TestClock.now
    private let colourTiming = VisitTiming(prepMinutes: 10, cleanupMinutes: 15, processingStartMinutes: 30,
                                           processingMinutes: 45)

    private func json(_ value: some Encodable) throws -> Data {
        try CallableJSON.encoder.encode(value)
    }

    private func inputs() -> PublishInputs {
        let colour = Service(name: "Colour", durationMinutes: 90, position: 0, timing: colourTiming)
        let glow = Service(name: "Glow", durationMinutes: 60, position: 1)
        var visit = makeVisit(hours: 3, minutes: 90)
        visit.serviceID = colour.id
        var inputs = makePublishInputs(services: [colour, glow], appointments: [visit], blocks: [makeBlock(hours: 6)])
        inputs.availability.slotStepMinutes = 20
        inputs.availability.compactDay = false
        return inputs
    }

    @Test("A service sends its extra and processing time; a plain one sends none")
    func services() {
        let sent = PublishPayloads.profile(inputs(), now: now).profile.services
        #expect(sent.first?.prepMinutes == 10 && sent.first?.cleanupMinutes == 15)
        #expect(sent.first?.processingStartMinutes == 30 && sent.first?.processingMinutes == 45)
        #expect(sent.last?.prepMinutes == nil && sent.last?.processingMinutes == nil)
    }

    @Test("Processing that does not fit the visit is not sent")
    func misfit() {
        let fields = PublishTimingFields(VisitTiming(processingStartMinutes: 50, processingMinutes: 45),
                                         visibleMinutes: 60)
        #expect(fields.processingMinutes == nil && fields.processingStartMinutes == nil)
        #expect(PublishTimingFields(VisitTiming(prepMinutes: 90), visibleMinutes: 60).prepMinutes == 60)
    }

    @Test("The availability carries the slot interval, the compact day and the shape of her own visits")
    func availability() {
        let sent = PublishPayloads.availability(inputs(), now: now)
        #expect(sent.slotStepMinutes == 20 && !sent.compactDay)
        let visit = sent.busy.first { $0.kind == "appointment" }
        #expect(visit?.cleanupMinutes == 15 && visit?.processingMinutes == 45)
        #expect(sent.busy.first { $0.kind == "block" }?.prepMinutes == nil)
        #expect(PublishPayloads.availability(makePublishInputs(), now: now).slotStepMinutes == 15)
    }

    @Test("The smart-slot fields satisfy the backend's published schemas")
    func contract() throws {
        let both = inputs()
        let page = try ServerContract.violations(of: json(PublishPayloads.profile(both, now: now)),
                                                 for: "publishProfile")
        let hours = try ServerContract.violations(of: json(PublishPayloads.availability(both, now: now)),
                                                  for: "publishAvailability")
        for problem in page + hours { Issue.record(Comment(rawValue: problem)) }
    }
}
