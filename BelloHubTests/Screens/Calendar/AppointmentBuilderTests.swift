//
//  AppointmentBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AppointmentBuilder")
struct AppointmentBuilderTests {
    private let start = friday("10:00")

    private func choice(
        visitType: VisitType = .treatment, addOns: [AddOn] = [], guests: [String] = [], linked: UUID? = nil
    ) -> AppointmentBuilder.Choice {
        AppointmentBuilder.Choice(
            clientID: UUID(), service: Service(name: "Glow Facial", durationMinutes: 60), visitType: visitType,
            addOns: addOns, guestNames: guests, startsAt: start, linkedAppointmentID: linked
        )
    }

    @Test("The visit copies the service name, the add-ons and the guests, and ends after the total time")
    func build() {
        let tint = AddOn(id: UUID(), name: "Eyebrow tint", minutes: 15, priceAmount: nil, isOffered: true, position: 0)
        let made = AppointmentBuilder.appointment(
            from: choice(addOns: [tint], guests: ["  Bia ", ""]), id: UUID(), now: TestClock.now
        )
        #expect(made.serviceName == "Glow Facial")
        #expect(made.totalMinutes == 60 + 15 + 120)
        #expect(made.endsAt == start.addingTimeInterval(TimeInterval(made.totalMinutes * 60)))
        #expect(made.addOns == [AppointmentAddOn(addOnID: tint.id, name: "Eyebrow tint", minutes: 15)])
        #expect(made.guests == ["Bia", ""])
        #expect(made.status == .booked && made.origin == .manual)
        #expect(made.createdAt == TestClock.now)
    }

    @Test("Only a reaction check keeps its link to the earlier visit")
    func link() {
        let earlier = UUID()
        #expect(AppointmentBuilder.appointment(from: choice(visitType: .reactionCheck, linked: earlier),
                                               now: TestClock.now).linkedAppointmentID == earlier)
        #expect(AppointmentBuilder.appointment(from: choice(visitType: .treatment, linked: earlier),
                                               now: TestClock.now).linkedAppointmentID == nil)
    }

    @Test("The visit a reaction check looks at is the latest one before it that was not cancelled")
    func visitToCheck() {
        let client = UUID()
        let old = makeVisit(clientID: client, start: TestClock.date("2026-09-10 10:00"), status: .completed)
        let recent = makeVisit(clientID: client, start: TestClock.date("2026-09-28 10:00"), status: .completed)
        let cancelled = makeVisit(clientID: client, start: TestClock.date("2026-09-30 10:00"), status: .cancelled)
        let later = makeVisit(clientID: client, start: TestClock.date("2026-10-20 10:00"))
        let found = AppointmentBuilder.visitToCheck(among: [old, recent, cancelled, later], before: start)
        #expect(found?.id == recent.id)
        #expect(AppointmentBuilder.visitToCheck(among: [], before: start) == nil)
    }
}
