//
//  ManualBookingAuditTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Characterization probes for the audit: these demonstrate current behavior, not acceptance of that behavior.
@Suite("Manual booking audit")
@MainActor
struct ManualBookingAuditTests {
    @Test("F02: successful registration leaves the original local visit unlinked and import adds a second visit")
    func registeredManualVisitDuplicatesOnImport() async throws {
        let world = try await CalendarWorld.make()
        let inbox = FakeInboxRepository()
        let links = ClientLinkService(repository: inbox, now: { TestClock.now })
        let model = NewAppointmentViewModel(
            clientID: world.ana.id, startsAt: friday("10:00"), timeZoneID: "America/Sao_Paulo",
            appointments: world.appointments, timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup,
            vault: world.vault, profileService: world.profile, clientLinks: links, now: { TestClock.now }
        )
        await model.loadAsync()
        #expect(await model.bookAsync())
        #expect(model.exclusiveManageLink != nil)
        let visits = try await world.appointments.appointments(for: world.ana.id)
        let original = try #require(visits.first)
        #expect(original.bookingID == nil)
        let booking = IncomingBooking(
            id: original.id.uuidString.lowercased(), status: .confirmed, serviceId: "manual",
            serviceName: original.serviceName, durationMinutes: original.totalMinutes,
            startsAt: original.startsAt, endsAt: original.endsAt, timeZoneID: "America/Sao_Paulo",
            client: .init(name: world.ana.name, phone: world.ana.phoneE164 ?? "", email: nil, locale: "pt-BR"),
            origin: "manual", policy: .standard, createdAt: TestClock.now
        )
        let plan = BookingImporter.plan(
            bookings: [booking], appointments: visits, clients: [world.ana], services: model.services,
            now: TestClock.now
        )
        #expect(plan.appointments.count == 1)
        #expect(plan.appointments.first?.id != original.id)
        #expect(plan.conflicts.count == 1)
        #expect(LinkVisitChange.change(
            from: original, to: AppointmentTransitions.rescheduled(original, to: friday("15:00"), now: TestClock.now)
        ) == nil)
    }

    @Test("F04: an offline registration still reports booking success and leaves no linked booking")
    func offlineRegistrationIsNotRetriedByBooking() async throws {
        let world = try await CalendarWorld.make()
        let inbox = FakeInboxRepository()
        await inbox.setWriteFailure(.unreachable)
        let links = ClientLinkService(repository: inbox, now: { TestClock.now })
        let model = NewAppointmentViewModel(
            clientID: world.ana.id, startsAt: friday("10:00"), timeZoneID: "America/Sao_Paulo",
            appointments: world.appointments, timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup,
            vault: world.vault, profileService: world.profile, clientLinks: links, now: { TestClock.now }
        )
        await model.loadAsync()
        #expect(await model.bookAsync())
        #expect(model.didBook && model.saveErrorMessage == nil && model.exclusiveManageLink == nil)
        let visits = try await world.appointments.appointments(for: world.ana.id)
        #expect(visits.count == 1 && visits.first?.bookingID == nil)
    }
}
