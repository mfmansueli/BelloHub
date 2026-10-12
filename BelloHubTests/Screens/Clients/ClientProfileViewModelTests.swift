//
//  ClientProfileViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("ClientProfileViewModel", .serialized)
struct ClientProfileViewModelTests {
    private func makeModel(_ world: ClientsWorld, client: Client, phone: FakePhoneLauncher = FakePhoneLauncher())
        -> ClientProfileViewModel {
        ClientProfileViewModel(
            clientID: client.id, vault: world.vault, profile: world.profile, phone: phone, now: { TestClock.now }
        )
    }

    private func loaded(_ model: ClientProfileViewModel) async -> Bool {
        await Wait.untilMain { model.snapshot != nil }
    }

    @Test("The profile loads the client, her habits and her last and next visit")
    func loads() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana Costa", phone: "+5511981234410")
        try await world.repository.save(ana)
        try await world.repository.save(makeAppointment(clientID: ana.id, daysFromNow: -30, serviceName: "Glow Facial"))
        try await world.repository.save(makeAppointment(clientID: ana.id, daysFromNow: 2, status: .booked))
        let model = makeModel(world, client: ana)

        model.startListening()
        defer { model.stopListening() }

        #expect(await loaded(model))
        let snapshot = try #require(model.snapshot)
        #expect(snapshot.client.name == "Ana Costa")
        #expect(snapshot.habits.visits == 1)
        #expect(snapshot.lastVisit?.serviceName == "Glow Facial")
        #expect(snapshot.nextAppointment != nil)
        #expect(!model.isLoading && !model.isMissing && model.errorMessage == nil)
    }

    @Test("An edit shows at once: the profile follows the client record")
    func followsTheClient() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana Costa")
        try await world.repository.save(ana)
        let model = makeModel(world, client: ana)
        model.startListening()
        defer { model.stopListening() }
        #expect(await loaded(model))

        var renamed = ana
        renamed.name = "Ana C. Costa"
        renamed.sensitivities = ["Cheeks"]
        try await world.repository.save(renamed)

        #expect(await Wait.untilMain { model.snapshot?.client.name == "Ana C. Costa" })
        #expect(model.snapshot?.client.sensitivities == ["Cheeks"])
    }

    @Test("A new appointment shows at once: the profile follows the calendar")
    func followsAppointments() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana Costa")
        try await world.repository.save(ana)
        let model = makeModel(world, client: ana)
        model.startListening()
        defer { model.stopListening() }
        #expect(await loaded(model))
        #expect(model.snapshot?.nextAppointment == nil)

        try await world.repository.save(makeAppointment(clientID: ana.id, daysFromNow: 5, status: .confirmed))

        #expect(await Wait.untilMain { model.snapshot?.nextAppointment != nil })
    }

    // MARK: - Timeline

    @Test("A walk-in visit recorded with no appointment and no portal shows on the timeline with its photos")
    func walkInVisit() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana")
        try await world.repository.save(ana)
        let record = TreatmentRecord(clientID: ana.id, serviceName: "Brows", createdAt: TestClock.now,
                                     performedAt: TestClock.days(-1), technique: "Henna")
        try await world.repository.save(record)
        let photo = Photo(id: UUID(), clientID: ana.id, recordID: record.id, takenAt: TestClock.now, kind: .after,
                          visibility: .professionalOnly)
        try await world.repository.save(photo, data: PhotoData(image: Data([1]), thumbnail: Data([2])))
        let model = makeModel(world, client: ana)
        model.startListening()
        defer { model.stopListening() }

        #expect(await Wait.untilMain { model.timeline.lastVisit?.id == record.id })
        #expect(model.timeline.lastVisit?.photos.map(\.id) == [photo.id])
        #expect(model.timeline.lastVisit?.visitDate.source == .recorded)
        #expect(model.section == .history, "History opens first")
        #expect(await model.thumbnail(for: photo) == Data([2]))
    }

    @Test("Registering from the record starts a visit with no appointment; a pending booking starts its own")
    func requests() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana")
        try await world.repository.save(ana)
        let done = makeAppointment(clientID: ana.id, daysFromNow: -1)
        try await world.repository.save(done)
        let model = makeModel(world, client: ana)
        model.startListening()
        defer { model.stopListening() }

        #expect(await Wait.untilMain { model.timeline.pendingRecords.map(\.id) == [done.id] })
        #expect(model.newVisitRequest.appointmentID == nil)
        #expect(model.newVisitRequest.clientID == ana.id)
        #expect(model.pendingRecordRequest(for: done).appointmentID == done.id)
    }

    @Test("A client who is gone (merged or deleted) is said to be gone, not shown empty")
    func missingClient() async throws {
        let world = try await ClientsWorld.make()
        let model = makeModel(world, client: makeListedClient())

        model.startListening()
        defer { model.stopListening() }

        #expect(await Wait.untilMain { model.isMissing })
        #expect(model.snapshot == nil && !model.isLoading)
    }

    @Test("A profile that is open when the client is deleted turns into the 'gone' state")
    func deletedWhileOpen() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana")
        try await world.repository.save(ana)
        let model = makeModel(world, client: ana)
        model.startListening()
        defer { model.stopListening() }
        #expect(await loaded(model))

        try await world.repository.deleteClient(id: ana.id)

        #expect(await Wait.untilMain { model.isMissing })
    }

    @Test("A vault that cannot be opened is an error")
    func unavailableVault() {
        let (vault, profile) = ClientsWorld.unavailable()
        let model = ClientProfileViewModel(clientID: UUID(), vault: vault, profile: profile, phone: FakePhoneLauncher())

        model.startListening()

        #expect(model.errorMessage != nil && !model.isLoading)
    }

    // MARK: - Call

    @Test("Call places the call to her number in international form")
    func call() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana", phone: "+5511981234410")
        try await world.repository.save(ana)
        let phone = FakePhoneLauncher()
        let model = makeModel(world, client: ana, phone: phone)
        await model.refreshAsync()

        #expect(model.canCall)
        await model.callAsync()

        #expect(phone.dialed == ["+5511981234410"])
        #expect(!model.callFailed)
    }

    @Test("A phone that cannot call is said so, and the message can be dismissed")
    func callFailure() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana", phone: "+5511981234410")
        try await world.repository.save(ana)
        let phone = FakePhoneLauncher()
        phone.canPlaceCalls = false
        let model = makeModel(world, client: ana, phone: phone)
        await model.refreshAsync()

        await model.callAsync()
        #expect(model.callFailed)

        model.dismissCallFailure()
        #expect(!model.callFailed)
    }

    @Test("Without a number there is no Call, and nothing is dialed")
    func noNumber() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana")
        try await world.repository.save(ana)
        let phone = FakePhoneLauncher()
        let model = makeModel(world, client: ana, phone: phone)
        await model.refreshAsync()

        await model.callAsync()

        #expect(!model.canCall && phone.dialed.isEmpty)
    }

    // MARK: - Labels

    @Test("The labels under her name resolve her tags by name")
    func chips() async throws {
        let world = try await ClientsWorld.make()
        let tag = try #require(world.tags.first)
        var ana = makeListedClient(name: "Ana", tagIDs: [tag.id])
        ana.onlineBookingStopped = true
        try await world.repository.save(ana)
        let model = makeModel(world, client: ana)
        await model.refreshAsync()

        #expect(model.chips == [.tag(tag.name), .onlineBookingStopped])
    }
}
