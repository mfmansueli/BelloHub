//
//  ClientEditViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The edit screen (4.3): the same form ViewModel in edit mode, with archive and restore.
@MainActor
@Suite("ClientFormViewModel (edit)", .serialized)
struct ClientEditViewModelTests {
    private func editModel(_ world: ClientsWorld, _ client: Client, registrar: any ClientRegistering) async
        -> ClientFormViewModel {
        let model = ClientFormViewModel(
            mode: .edit(clientID: client.id), registrar: registrar, vault: world.vault, profile: world.profile,
            regions: world.regions, now: { TestClock.now }
        )
        await model.load()
        return model
    }

    // MARK: - Edit

    @Test("The edit form starts from the client and cannot be saved until something changes")
    func editStartsClean() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana Costa", phone: "+5511981234410", email: "ana@example.com")
        try await world.repository.save(ana)

        let model = await editModel(world, ana, registrar: FakeClientRegistrar())

        #expect(model.draft.name == "Ana Costa" && model.draft.email == "ana@example.com")
        #expect(!model.isDirty && !model.canSave && !model.isLoading)

        model.draft.name = "Ana C. Costa"
        #expect(model.isDirty && model.canSave)
    }

    @Test("Saving an edit goes through the gate as an update and never counts against the free registrations")
    func editNeverCounts() async throws {
        let world = try await ClientsWorld.make()
        for index in 0..<RegistrationQuota.freeLimit {
            try await world.repository.save(makeListedClient(name: "Client \(index)"))
        }
        let ana = try #require(try await world.repository.allClients().first)
        let gate = ClientRegistrationService(vault: world.vault)
        let model = await editModel(world, ana, registrar: gate)
        model.draft.name = "Renamed"
        model.draft.remindersEnabled = false

        await model.saveAsync()

        #expect(model.finish == .updated(ana.id))
        let stored = try #require(try await world.repository.client(id: ana.id))
        #expect(stored.name == "Renamed" && !stored.remindersEnabled)
        #expect(try await world.repository.registrationLedger().count == RegistrationQuota.freeLimit)
    }

    @Test("An edit that gives a client another client's number is refused with the notice, and saves nothing")
    func editDuplicate() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana", phone: "+5511981234410")
        let bia = makeListedClient(name: "Bia", phone: "+5511970001111")
        try await world.repository.save(ana)
        try await world.repository.save(bia)
        let model = await editModel(world, bia, registrar: ClientRegistrationService(vault: world.vault))
        model.draft.phone = "+55 11 98123-4410"

        await model.saveAsync()

        #expect(model.duplicateNotice == ana.id && model.finish == nil)
        #expect(try await world.repository.client(id: bia.id)?.phoneE164 == "+5511970001111")
    }

    @Test("Stopping online booking saves the reason with the client")
    func stopBooking() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana Costa")
        try await world.repository.save(ana)
        let model = await editModel(world, ana, registrar: ClientRegistrationService(vault: world.vault))
        model.draft.onlineBookingStopped = true
        model.draft.stopReason = "Asked to pause"

        await model.saveAsync()

        let stored = try #require(try await world.repository.client(id: ana.id))
        #expect(stored.onlineBookingStopped && stored.stopReason == "Asked to pause")
    }

    @Test("A bad email in an edit is refused and the client is left as she was")
    func editInvalidEmail() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana")
        try await world.repository.save(ana)
        let registrar = FakeClientRegistrar()
        let model = await editModel(world, ana, registrar: registrar)
        model.draft.email = "ana@"

        await model.saveAsync()

        #expect(model.emailIssue == .emailInvalid && registrar.registered.isEmpty)
    }

    // MARK: - Archive and restore

    @Test("Archiving saves the client as archived, with whatever else was in the form")
    func archive() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana Costa")
        try await world.repository.save(ana)
        let model = await editModel(world, ana, registrar: ClientRegistrationService(vault: world.vault))
        model.draft.email = "ana@example.com"

        model.setArchived(true)
        #expect(await Wait.untilMain { model.finish != nil })

        #expect(model.finish == .archived(ana.id))
        let stored = try #require(try await world.repository.client(id: ana.id))
        #expect(stored.isArchived && stored.email == "ana@example.com")
    }

    @Test("Restoring brings an archived client back to the lists")
    func restore() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana Costa", isArchived: true)
        try await world.repository.save(ana)
        let model = await editModel(world, ana, registrar: ClientRegistrationService(vault: world.vault))

        model.setArchived(false)
        #expect(await Wait.untilMain { model.finish != nil })

        #expect(model.finish == .restored(ana.id))
        #expect(try await world.repository.client(id: ana.id)?.isArchived == false)
    }

    @Test("The current year is the Gregorian year of the business time zone, whatever calendar the phone uses")
    func currentYear() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana")
        try await world.repository.save(ana)

        let model = await editModel(world, ana, registrar: FakeClientRegistrar())

        #expect(model.currentYear == 2026)
    }

    @Test("Editing a client who is gone says so instead of showing an empty form")
    func editMissing() async throws {
        let world = try await ClientsWorld.make()

        let model = await editModel(world, makeListedClient(), registrar: FakeClientRegistrar())

        #expect(model.isMissing && !model.isLoading && !model.canSave)
    }

    @Test("A vault that cannot be opened is an error on the edit form")
    func editUnavailable() async {
        let (vault, profile) = ClientsWorld.unavailable()
        let model = ClientFormViewModel(
            mode: .edit(clientID: UUID()), registrar: FakeClientRegistrar(), vault: vault, profile: profile
        )

        await model.load()

        #expect(model.errorMessage != nil && !model.isLoading)
    }
}
