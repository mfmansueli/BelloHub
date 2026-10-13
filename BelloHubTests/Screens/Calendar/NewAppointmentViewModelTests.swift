//
//  NewAppointmentViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("NewAppointmentViewModel")
@MainActor
struct NewAppointmentViewModelTests {
    private func makeModel(
        _ world: CalendarWorld, clientID: UUID? = nil, startsAt: Date? = nil,
        appointments: AppointmentService? = nil,
        catalog: FakeHealthFormCatalogProvider = FakeHealthFormCatalogProvider()
    ) -> NewAppointmentViewModel {
        NewAppointmentViewModel(
            clientID: clientID, startsAt: startsAt, timeZoneID: "America/Sao_Paulo",
            appointments: appointments ?? world.appointments, timeBlocks: world.timeBlocks,
            bookingSetup: world.bookingSetup, vault: world.vault, catalogProvider: catalog, now: { TestClock.now }
        )
    }

    private func loaded(
        _ world: CalendarWorld, clientID: UUID? = nil, startsAt: Date? = nil
    ) async -> NewAppointmentViewModel {
        let model = makeModel(world, clientID: clientID, startsAt: startsAt)
        await model.loadAsync()
        return model
    }

    // MARK: - Loading

    @Test("Loading lists the clients by name and the active services, and chooses the first service")
    func load() async throws {
        let world = try await CalendarWorld.make()
        var off = world.deep
        off.isActive = false
        try await world.repository.save(off)
        let model = await loaded(world)
        #expect(model.hasLoaded && model.errorMessage == nil)
        #expect(model.clients.map(\.name) == ["Ana Costa", "Beatriz Lima"])
        #expect(model.services.map(\.name) == ["Glow Facial"])
        #expect(model.selectedService?.name == "Glow Facial")
    }

    @Test("Only offered add-ons can be chosen")
    func addOns() async throws {
        let world = try await CalendarWorld.make()
        let offered = AddOn(id: UUID(), name: "LED light", minutes: 15, priceAmount: nil, isOffered: true, position: 0)
        let hidden = AddOn(
            id: UUID(), name: "Extractions", minutes: 20, priceAmount: nil, isOffered: false, position: 1
        )
        try await world.repository.save(offered)
        try await world.repository.save(hidden)
        let model = await loaded(world)
        #expect(model.addOns.map(\.name) == ["LED light"])
    }

    @Test("A vault that cannot be opened says so")
    func unavailable() async throws {
        let world = try await CalendarWorld.make()
        let vault = VaultService(repository: nil)
        let model = NewAppointmentViewModel(
            clientID: nil, startsAt: nil, timeZoneID: "America/Sao_Paulo", appointments: world.appointments,
            timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup, vault: vault
        )
        await model.loadAsync()
        #expect(model.errorMessage != nil)
        #expect(!model.canBook)
    }

    // MARK: - Choosing

    @Test("The search narrows the clients, the chosen one comes first, and archived ones are left out")
    func search() async throws {
        let world = try await CalendarWorld.make()
        let archived = Client(name: "Ana Archived", isArchived: true, createdAt: TestClock.days(-9))
        _ = try await world.repository.save(archived)
        let model = await loaded(world)
        #expect(model.visibleClients.map(\.name) == ["Ana Costa", "Beatriz Lima"])
        model.searchText = "bea"
        #expect(model.visibleClients.map(\.name) == ["Beatriz Lima"])
        model.searchText = ""
        model.selectClient(world.beatriz.id)
        #expect(model.visibleClients.first?.id == world.beatriz.id)
    }

    @Test("The total is the service plus add-ons plus each guest in sequence, and the end follows")
    func total() async throws {
        let world = try await CalendarWorld.make()
        let led = AddOn(id: UUID(), name: "LED light", minutes: 15, priceAmount: nil, isOffered: true, position: 0)
        try await world.repository.save(led)
        let model = await loaded(world, startsAt: friday("10:00"))
        #expect(model.totalMinutes == 60 && model.endsAt == friday("11:00"))
        model.toggleAddOn(led.id)
        model.addGuest()
        model.addGuest()
        #expect(model.totalMinutes == 60 + 15 + 120)
        model.removeGuest(at: 0)
        #expect(model.totalMinutes == 60 + 15 + 60)
        model.toggleAddOn(led.id)
        #expect(model.totalMinutes == 120)
        #expect(model.endsAt == friday("12:00"))
    }

    @Test("Guests are capped, and a visit longer than twelve hours cannot be booked")
    func limits() async throws {
        let world = try await CalendarWorld.make()
        let long = Service(name: "Protocol 360", durationMinutes: 300, position: 2)
        try await world.repository.save(long)
        let model = await loaded(world, clientID: world.ana.id, startsAt: friday("10:00"))
        model.selectService(long.id)
        for _ in 0..<10 { model.addGuest() }
        #expect(model.guestNames.count == NewAppointmentViewModel.maximumGuests)
        #expect(model.exceedsMaximumDuration)
        #expect(!model.canBook)
    }

    @Test("Choosing a day forgets the time; choosing a time keeps the day")
    func dayAndTime() async throws {
        let world = try await CalendarWorld.make()
        let model = await loaded(world, startsAt: friday("10:00"))
        #expect(model.day == TestClock.date("2026-10-02 00:00"))
        model.selectDay(TestClock.date("2026-10-03 15:30"))
        #expect(model.day == TestClock.date("2026-10-03 00:00") && model.start == nil)
        model.selectTime(minutes: 14 * 60 + 15)
        #expect(model.start == TestClock.date("2026-10-03 14:15"))
        model.selectStart(TestClock.date("2026-10-03 16:00"))
        #expect(model.start == TestClock.date("2026-10-03 16:00"))
    }

    @Test("The free times of the day fit the whole visit")
    func slots() async throws {
        let world = try await CalendarWorld.make()
        let blocking = makeVisit(start: friday("10:00"), minutes: 60)
        try await world.appointments.book(blocking)
        let model = await loaded(world, startsAt: friday("15:00"))
        await model.loadAsync()
        _ = await Wait.untilMain { model.context.appointments.count == 1 }
        #expect(!model.slots.contains(friday("10:00")))
        #expect(model.slots.contains(friday("15:00")))
        #expect(model.slots.allSatisfy { $0 >= friday("09:00") })
    }

    // MARK: - Warnings

    @Test("An occupied time warns and cannot be booked")
    func overlapIsHerDecision() async throws {
        let world = try await CalendarWorld.make()
        let existing = makeVisit(clientID: world.beatriz.id, start: friday("10:00"))
        try await world.appointments.book(existing)
        let model = makeModel(world, clientID: world.ana.id, startsAt: friday("10:30"))
        await model.loadAsync()
        #expect(model.warnings.contains(.overlap(with: existing.id)))
        #expect(model.hasScheduleConflict && !model.canBook)
        #expect(model.clientName(for: existing.id) == "Beatriz Lima")
        #expect(await model.bookAsync() == false)
        #expect(try await world.appointments.appointments(for: world.ana.id).isEmpty)
        let sameClient = makeModel(world, clientID: world.beatriz.id, startsAt: friday("10:30"))
        await sameClient.loadAsync()
        #expect(!sameClient.canBook)
        #expect(await sameClient.bookAsync() == false)
    }

    @Test("A contraindication that matches the client's health form warns; the form of another client does not")
    func contraindication() async throws {
        let world = try await CalendarWorld.make()
        let service = Service(
            name: "Peel", durationMinutes: 45, position: 3, contraindications: ["pregnancy"]
        )
        try await world.repository.save(service)
        try await world.repository.save(makeHealthForm(clientID: world.ana.id, answers: ["pregnancy": .yes]))
        try await world.repository.save(makeHealthForm(clientID: world.beatriz.id, answers: ["pregnancy": .no]))
        let model = await loaded(world, clientID: world.ana.id, startsAt: friday("10:00"))
        model.selectService(service.id)
        #expect(model.warnings.contains { if case .contraindicated = $0 { true } else { false } })
        model.selectClient(world.beatriz.id)
        _ = await Wait.untilMain { model.context.form?.clientID == world.beatriz.id }
        #expect(model.warnings.isEmpty)
    }

    @Test("A missing patch test warns, and logging a clean one before the visit clears it")
    func patchTest() async throws {
        let world = try await CalendarWorld.make()
        let service = Service(name: "Brazilian Glow", durationMinutes: 90, position: 3, requiresPatchTest: true)
        try await world.repository.save(service)
        let model = await loaded(world, clientID: world.ana.id, startsAt: friday("10:00"))
        model.selectService(service.id)
        #expect(model.warnings.contains(.missingPatchTest(hoursBefore: 48)))
        let test = PatchTest(
            id: UUID(), clientID: world.ana.id, testedAt: TestClock.days(-1), observedHours: 48, product: "Serum",
            area: nil, result: .noReaction, notes: nil
        )
        try await world.repository.save(test)
        model.selectClient(world.beatriz.id)
        model.selectClient(world.ana.id)
        _ = await Wait.untilMain { model.context.patchTests.count == 1 }
        #expect(!model.warnings.contains(.missingPatchTest(hoursBefore: 48)))
    }

    // MARK: - Booking

    @Test("Booking stores the visit with the service, add-ons, guests and type she chose")
    func book() async throws {
        let world = try await CalendarWorld.make()
        let led = AddOn(id: UUID(), name: "LED light", minutes: 15, priceAmount: nil, isOffered: true, position: 0)
        try await world.repository.save(led)
        let model = await loaded(world, clientID: world.ana.id, startsAt: friday("10:00"))
        model.visitType = .touchUp
        model.toggleAddOn(led.id)
        model.addGuest()
        model.setGuestName("Bia", at: 0)
        #expect(await model.bookAsync())
        let stored = try #require(try await world.appointments.appointments(for: world.ana.id).first)
        #expect(stored.serviceName == "Glow Facial" && stored.serviceID == world.glow.id)
        #expect(stored.visitType == .touchUp && stored.guests == ["Bia"])
        #expect(stored.addOns.map(\.name) == ["LED light"])
        #expect(stored.totalMinutes == 60 + 15 + 60)
        #expect(stored.startsAt == friday("10:00") && stored.endsAt == friday("12:15"))
        #expect(stored.status == .booked && stored.origin == .manual)
        #expect(model.didBook)
    }

    @Test("A reaction check points at the client's latest earlier visit")
    func reactionCheck() async throws {
        let world = try await CalendarWorld.make()
        let earlier = makeVisit(
            clientID: world.ana.id, start: TestClock.date("2026-09-28 10:00"), status: .completed
        )
        try await world.appointments.book(earlier)
        let model = await loaded(world, clientID: world.ana.id, startsAt: friday("10:00"))
        model.visitType = .reactionCheck
        #expect(await model.bookAsync())
        let stored = try await world.appointments.appointments(for: world.ana.id)
        #expect(stored.first { $0.visitType == .reactionCheck }?.linkedAppointmentID == earlier.id)
    }

    @Test("Without a client, a service and a time the visit cannot be booked")
    func incomplete() async throws {
        let world = try await CalendarWorld.make()
        let model = await loaded(world)
        #expect(!model.canBook)
        #expect(await model.bookAsync() == false)
        model.selectClient(world.ana.id)
        #expect(!model.canBook)
        model.selectStart(friday("10:00"))
        #expect(model.canBook)
    }

    @Test("A failed save changes nothing and says so")
    func saveFails() async throws {
        let world = try await CalendarWorld.make()
        let failing = FakeAgendaRepository(inner: world.memory)
        await failing.setFailsWrites(true)
        let model = makeModel(
            world, clientID: world.ana.id, startsAt: friday("10:00"),
            appointments: AppointmentService(repository: failing)
        )
        await model.loadAsync()
        #expect(await model.bookAsync() == false)
        #expect(model.saveErrorMessage != nil && !model.didBook && !model.isSaving)
        #expect(try await world.appointments.appointments(for: world.ana.id).isEmpty)
        model.dismissSaveError()
        #expect(model.saveErrorMessage == nil)
    }

    @Test("A client who was just added is chosen and her context is read")
    func newClient() async throws {
        let world = try await CalendarWorld.make()
        let model = await loaded(world, startsAt: friday("10:00"))
        let helena = Client(name: "Helena Duarte", createdAt: TestClock.now)
        _ = try await world.repository.save(helena)
        await model.clientWasAdded(helena.id)
        #expect(model.clientID == helena.id && model.clients.contains { $0.id == helena.id })
    }
}

// MARK: - Booking Confirmation

extension NewAppointmentViewModelTests {
    @Test("Booking sets didBook and produces the confirmation message for the client")
    func bookingConfirmation() async throws {
        let world = try await CalendarWorld.make()
        let model = await loaded(world, clientID: world.ana.id, startsAt: friday("10:00"))

        let booked = await model.bookAsync()
        #expect(booked)
        #expect(model.didBook)

        let formatters = Formatters(
            locale: Locale(identifier: "pt_BR"), timeZone: TestClock.saoPaulo, currencyCode: "BRL"
        )
        let message = model.confirmationMessageText(formatters: formatters)
        #expect(message.contains("Ana"))
        #expect(message.contains("Glow Facial"))

        await model.sendConfirmationWhatsApp(messageText: message)
        #expect(model.confirmationOutcome != nil)
    }
}

// MARK: - Business time zone (fix-reschedule-day)

extension NewAppointmentViewModelTests {
    @Test("A day chosen in the calendar's zone offers that day's hours, whatever zone her hours were saved in",
          arguments: ZoneMismatch.all)
    func businessZone(_ zones: ZoneMismatch) async throws {
        let world = try await CalendarWorld.make(availability: zones.availability)
        let model = NewAppointmentViewModel(
            clientID: nil, startsAt: nil, timeZoneID: zones.business, appointments: world.appointments,
            timeBlocks: world.timeBlocks, bookingSetup: world.bookingSetup, vault: world.vault,
            catalogProvider: FakeHealthFormCatalogProvider(), now: { TestClock.now }
        )
        await model.loadAsync()
        model.selectService(world.glow.id)
        model.selectDay(zones.day)
        let times = model.slotPlan.all
        #expect(times.first == zones.at("09:00"))
        #expect(times.last == zones.at("17:00"))
        #expect(times.allSatisfy { zones.days.isSameDay($0, zones.day) })
        model.selectTime(minutes: 9 * 60)
        #expect(model.start == zones.at("09:00"))
        #expect(model.warnings.filter(\.isScheduleConflict).isEmpty, "09:00 is inside her hours")
    }
}
