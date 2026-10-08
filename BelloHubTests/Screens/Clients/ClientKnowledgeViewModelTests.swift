//
//  ClientKnowledgeViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("ClientKnowledgeViewModel", .serialized)
struct ClientKnowledgeViewModelTests {
    private func makeClient() -> Client {
        var client = makeListedClient(name: "Ana Costa", importantNote: "Sensitive skin")
        client.sensitivities = ["Cheeks", "Eyes"]
        client.preferences = ["Fragrance-free"]
        client.recurringRequests = ["Gentle pressure"]
        return client
    }

    private func loadedModel(
        _ world: ClientsWorld, registrar: any ClientRegistering, client: Client? = nil
    ) async throws -> (ClientKnowledgeViewModel, Client) {
        let client = client ?? makeClient()
        try await world.repository.save(client)
        let model = ClientKnowledgeViewModel(clientID: client.id, registrar: registrar, vault: world.vault)
        await model.load()
        return (model, client)
    }

    @Test("The screen starts from what she wrote: the note and the three lists")
    func loads() async throws {
        let world = try await ClientsWorld.make()
        let (model, _) = try await loadedModel(world, registrar: FakeClientRegistrar())

        #expect(model.note == "Sensitive skin")
        #expect(model.entries(in: .sensitivities) == ["Cheeks", "Eyes"])
        #expect(model.entries(in: .preferences) == ["Fragrance-free"])
        #expect(model.entries(in: .recurringRequests) == ["Gentle pressure"])
        #expect(model.firstName == "Ana")
        #expect(!model.isLoading && !model.isDirty)
    }

    @Test("Adding puts the entry at the end of its list and clears the field")
    func add() async throws {
        let world = try await ClientsWorld.make()
        let (model, _) = try await loadedModel(world, registrar: FakeClientRegistrar())
        model.pending[.preferences] = "  Quiet room "

        model.add(to: .preferences)

        #expect(model.entries(in: .preferences) == ["Fragrance-free", "Quiet room"])
        #expect(model.pending[.preferences] == "" && model.isDirty)
    }

    @Test("An entry already on the list is not added twice, and the screen is told which list")
    func addDuplicate() async throws {
        let world = try await ClientsWorld.make()
        let (model, _) = try await loadedModel(world, registrar: FakeClientRegistrar())
        model.pending[.sensitivities] = "cheeks"

        model.add(to: .sensitivities)

        #expect(model.entries(in: .sensitivities) == ["Cheeks", "Eyes"] && model.duplicateIn == .sensitivities)
    }

    @Test("Removing and reordering change only that list")
    func removeAndMove() async throws {
        let world = try await ClientsWorld.make()
        let (model, _) = try await loadedModel(world, registrar: FakeClientRegistrar())

        model.remove(at: IndexSet(integer: 0), from: .sensitivities)
        #expect(model.entries(in: .sensitivities) == ["Eyes"])
        #expect(model.entries(in: .preferences) == ["Fragrance-free"])

        model.pending[.recurringRequests] = "Warm towel"
        model.add(to: .recurringRequests)
        model.move(from: IndexSet(integer: 1), to: 0, in: .recurringRequests)
        #expect(model.entries(in: .recurringRequests) == ["Warm towel", "Gentle pressure"])
    }

    @Test("Done saves the note and the lists through the registration gate, as an update")
    func doneSaves() async throws {
        let world = try await ClientsWorld.make()
        let gate = ClientRegistrationService(vault: world.vault)
        let (model, client) = try await loadedModel(world, registrar: gate)
        model.note = "  Allergic to fragrance "
        model.remove(at: IndexSet(integer: 1), from: .sensitivities)
        model.pending[.preferences] = "Quiet room"

        await model.doneAsync()

        #expect(model.isFinished && model.errorMessage == nil)
        let stored = try #require(try await world.repository.client(id: client.id))
        #expect(stored.importantNote == "Allergic to fragrance")
        #expect(stored.sensitivities == ["Cheeks"])
        #expect(stored.preferences == ["Fragrance-free", "Quiet room"], "a half-typed entry is added by Done, not lost")
        #expect(stored.name == "Ana Costa" && stored.id == client.id)
    }

    @Test("Done never counts against the free registrations")
    func doneNeverCounts() async throws {
        let world = try await ClientsWorld.make()
        let gate = ClientRegistrationService(vault: world.vault)
        let (model, _) = try await loadedModel(world, registrar: gate)
        let before = try await world.repository.registrationLedger().count

        await model.doneAsync()

        #expect(try await world.repository.registrationLedger().count == before)
    }

    @Test("An emptied note is saved as no note")
    func emptyNote() async throws {
        let world = try await ClientsWorld.make()
        let gate = ClientRegistrationService(vault: world.vault)
        let (model, client) = try await loadedModel(world, registrar: gate)
        model.note = "   "

        await model.doneAsync()

        #expect(try await world.repository.client(id: client.id)?.importantNote == nil)
    }

    @Test("A gate that refuses is an error and the screen stays open")
    func refused() async throws {
        let world = try await ClientsWorld.make()
        let registrar = FakeClientRegistrar()
        registrar.outcome = .needsSubscription
        let (model, _) = try await loadedModel(world, registrar: registrar)

        await model.doneAsync()

        #expect(!model.isFinished && model.errorMessage != nil)
        model.dismissError()
        #expect(model.errorMessage == nil)
    }

    @Test("Changing the note counts as unsaved, and going back to the same text does not")
    func dirtyNote() async throws {
        let world = try await ClientsWorld.make()
        let (model, _) = try await loadedModel(world, registrar: FakeClientRegistrar())

        model.note = "Something else"
        #expect(model.isDirty)

        model.note = "Sensitive skin"
        #expect(!model.isDirty)
    }

    @Test("A client who is gone is said to be gone")
    func missing() async throws {
        let world = try await ClientsWorld.make()
        let model = ClientKnowledgeViewModel(clientID: UUID(), registrar: FakeClientRegistrar(), vault: world.vault)

        await model.load()

        #expect(model.isMissing && model.original == nil && !model.isLoading)
    }

    @Test("A vault that cannot be opened is an error that can be retried")
    func unavailable() async {
        let (vault, _) = ClientsWorld.unavailable()
        let model = ClientKnowledgeViewModel(clientID: UUID(), registrar: FakeClientRegistrar(), vault: vault)

        await model.load()

        #expect(model.errorMessage != nil && !model.isLoading)
        model.retry()
        #expect(await Wait.untilMain { model.errorMessage != nil && !model.isLoading })
    }
}
