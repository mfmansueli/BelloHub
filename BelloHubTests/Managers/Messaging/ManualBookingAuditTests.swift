//
//  ManualBookingAuditTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Regression probes for manual booking sync, including retry after a relaunch.
@Suite("Manual booking audit")
@MainActor
struct ManualBookingAuditTests {
    @Test("F01: a server conflict removes the provisional local visit and does not show success")
    func serverConflictRollsBackLocalVisit() async throws {
        let world = try await CalendarWorld.make()
        let inbox = FakeInboxRepository()
        await inbox.setWriteFailure(.conflict)
        let model = NewAppointmentViewModel(
            clientID: world.ana.id, startsAt: friday("10:00"), timeZoneID: "America/Sao_Paulo",
            appointments: world.appointments, timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup,
            vault: world.vault, profileService: world.profile,
            clientLinks: ClientLinkService(repository: inbox), now: { TestClock.now }
        )
        await model.loadAsync()
        #expect(await model.bookAsync() == false)
        #expect(!model.didBook && model.saveErrorMessage != nil)
        #expect(try await world.appointments.appointments(for: world.ana.id).isEmpty)
    }

    @Test("A permanent registration failure leaves the local visit visibly unlinked")
    func permanentFailureMarksVisit() async throws {
        let world = try await CalendarWorld.make()
        let inbox = FakeInboxRepository()
        await inbox.setWriteFailure(.rejected)
        let model = NewAppointmentViewModel(
            clientID: world.ana.id, startsAt: friday("10:00"), timeZoneID: "America/Sao_Paulo",
            appointments: world.appointments, timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup,
            vault: world.vault, profileService: world.profile,
            clientLinks: ClientLinkService(repository: inbox), now: { TestClock.now }
        )
        await model.loadAsync()
        #expect(await model.bookAsync())
        let visit = try #require((try await world.appointments.appointments(for: world.ana.id)).first)
        #expect(visit.bookingID == nil && visit.manualBookingSyncIssue == .failed)
    }

    @Test("F02: successful registration links the original visit and import updates it in place")
    func registeredManualVisitRemainsOneVisitOnImport() async throws {
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
        #expect(original.bookingID == original.id.uuidString.lowercased())
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
        #expect(plan.appointments.first?.id == original.id)
        #expect(plan.conflicts.isEmpty)
        #expect(LinkVisitChange.change(
            from: original, to: AppointmentTransitions.rescheduled(original, to: friday("15:00"), now: TestClock.now)
        ) != nil)
    }

    @Test("F02: a previously unlinked manual visit reconnects by its UUID during import")
    func oldManualVisitIsReconnected() async throws {
        let world = try await CalendarWorld.make()
        let original = makeVisit(clientID: world.ana.id, start: friday("10:00"))
        let booking = IncomingBooking(
            id: original.id.uuidString.lowercased(), status: .confirmed, serviceId: "manual",
            serviceName: original.serviceName, durationMinutes: original.totalMinutes,
            startsAt: original.startsAt, endsAt: original.endsAt, timeZoneID: "America/Sao_Paulo",
            client: .init(name: world.ana.name, phone: world.ana.phoneE164 ?? "", email: nil, locale: "pt-BR"),
            origin: "manual", policy: .standard, createdAt: TestClock.now
        )
        let plan = BookingImporter.plan(
            bookings: [booking], appointments: [original], clients: [world.ana], services: [], now: TestClock.now
        )
        #expect(plan.appointments.count == 1)
        #expect(plan.appointments.first?.id == original.id)
        #expect(plan.appointments.first?.bookingID == booking.id)
        #expect(plan.conflicts.isEmpty)
    }

    @Test("F04: an offline registration survives relaunch and links the original visit once online")
    func offlineRegistrationIsRetriedAfterRelaunch() async throws {
        let world = try await CalendarWorld.make()
        let inbox = FakeInboxRepository()
        await inbox.setWriteFailure(.unreachable)
        let suite = "test.manual.retry.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let keys = KeyManager(store: InMemoryKeyStore(seed: VaultVectors.entropy))
        func services() -> InboxServices {
            InboxServices.make(
                repository: inbox, keys: keys, vault: world.vault, appointments: world.appointments,
                pushProvider: FakePushTokenProvider(), defaults: defaults,
                retryDelays: [.seconds(600)], pollInterval: nil
            )
        }
        let first = services()
        first.bookings.startListening(userId: "manual-test")
        let model = NewAppointmentViewModel(
            clientID: world.ana.id, startsAt: friday("10:00"), timeZoneID: "America/Sao_Paulo",
            appointments: world.appointments, timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup,
            vault: world.vault, profileService: world.profile, clientLinks: first.clientLinks,
            now: { TestClock.now }
        )
        await model.loadAsync()
        #expect(await model.bookAsync())
        #expect(model.didBook && model.saveErrorMessage == nil && model.exclusiveManageLink == nil)
        let visits = try await world.appointments.appointments(for: world.ana.id)
        #expect(visits.count == 1 && visits.first?.bookingID == nil)
        let visit = try #require(visits.first)
        await Wait.untilMain { first.queue.pending.count == 1 && !first.queue.isFlushing }
        let queued = try #require(String(data: JSONEncoder().encode(first.queue.pending), encoding: .utf8))
        #expect(!queued.contains(world.ana.name))
        if let phone = world.ana.phoneE164 { #expect(!queued.contains(phone)) }
        first.bookings.stopListening()

        await inbox.setWriteFailure(nil)
        let relaunched = services()
        relaunched.bookings.startListening(userId: "manual-test")
        await Wait.untilMain { relaunched.queue.pending.isEmpty }
        #expect(relaunched.queue.pending.isEmpty)
        #expect(try await world.appointments.appointment(id: visit.id)?.bookingID == visit.id.uuidString.lowercased())
        let registrationCall = "registerManualBooking:\(visit.id.uuidString.lowercased())"
        #expect(await inbox.writes.filter { $0 == registrationCall }.count == 1)
        relaunched.bookings.stopListening()
    }

    @Test("F08: a late conflict stays on the visit until a moved time registers successfully")
    func lateConflictPersistsAndRescheduleRetries() async throws {
        let world = try await CalendarWorld.make()
        let inbox = FakeInboxRepository()
        await inbox.setWriteFailure(.unreachable)
        let suite = "test.manual.conflict.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let keys = KeyManager(store: InMemoryKeyStore(seed: VaultVectors.entropy))
        func services() -> InboxServices {
            InboxServices.make(
                repository: inbox, keys: keys, vault: world.vault, appointments: world.appointments,
                pushProvider: FakePushTokenProvider(), defaults: defaults,
                retryDelays: [.seconds(600)], pollInterval: nil
            )
        }
        let first = services()
        first.bookings.startListening(userId: "manual-conflict")
        let visit = makeVisit(clientID: world.ana.id, start: friday("10:00"))
        try await world.appointments.book(visit)
        first.clientLinks.retryManualBooking(id: visit.id, timeZoneID: "America/Sao_Paulo", locale: "pt-BR")
        await Wait.untilMain { first.queue.pending.count == 1 && !first.queue.isFlushing }

        await inbox.setWriteFailure(.conflict)
        first.queue.flush()
        await Wait.untilMain { first.queue.pending.isEmpty }
        let conflicted = try #require(try await world.appointments.appointment(id: visit.id))
        #expect(conflicted.bookingID == nil && conflicted.manualBookingSyncIssue == .conflict)
        let decoded = try JSONDecoder().decode(Appointment.self, from: JSONEncoder().encode(conflicted))
        #expect(decoded.manualBookingSyncIssue == .conflict)
        first.bookings.stopListening()

        await inbox.setWriteFailure(.unreachable)
        let relaunched = services()
        relaunched.bookings.startListening(userId: "manual-conflict")
        let reschedule = RescheduleViewModel(
            appointmentID: visit.id, timeZoneID: "America/Sao_Paulo",
            appointments: world.appointments, timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup,
            vault: world.vault, clientLinks: relaunched.clientLinks, locale: "pt-BR", now: { TestClock.now }
        )
        await reschedule.loadAsync()
        reschedule.selectStart(friday("15:00"))
        #expect(await reschedule.confirmAsync())
        await Wait.untilMain { relaunched.queue.pending.count == 1 && !relaunched.queue.isFlushing }

        await inbox.setWriteFailure(nil)
        relaunched.queue.flush()
        await Wait.untilMain { relaunched.queue.pending.isEmpty }
        let registered = try #require(try await world.appointments.appointment(id: visit.id))
        #expect(registered.startsAt == friday("15:00"))
        #expect(registered.bookingID == visit.id.uuidString.lowercased())
        #expect(registered.manualBookingSyncIssue == nil)
        relaunched.bookings.stopListening()
    }
}
