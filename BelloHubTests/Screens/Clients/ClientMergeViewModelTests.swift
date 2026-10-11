//
//  ClientMergeViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("ClientMergeViewModel", .serialized)
struct ClientMergeViewModelTests {
    private func makeWorld(with clients: [Client]) async throws -> ClientsWorld {
        let world = try await ClientsWorld.make()
        for client in clients { try await world.repository.save(client) }
        return world
    }

    @Test("The picker offers every other profile in reading order, never the one being kept")
    func candidates() async throws {
        let kept = makeListedClient(name: "Ana Costa")
        let world = try await makeWorld(with: [kept, makeListedClient(name: "Zoe"), makeListedClient(name: "Ana C.")])
        let model = ClientMergeViewModel(keptID: kept.id, vault: world.vault, profile: world.profile)

        await model.load()

        #expect(model.kept?.name == "Ana Costa")
        #expect(model.results.map(\.name) == ["Ana C.", "Zoe"])
        #expect(!model.isLoading && !model.hasNoCandidates)
    }

    @Test("Search narrows the profiles by name, phone or tag")
    func search() async throws {
        let kept = makeListedClient(name: "Ana Costa")
        let tag = Tag(id: UUID(), name: "Bridal", colorToken: "rose", position: 0)
        let world = try await makeWorld(with: [
            kept, makeListedClient(name: "Ana C.", phone: "+5511981234410"),
            makeListedClient(name: "Zoe", tagIDs: [tag.id])
        ])
        try await world.repository.save(tag)
        await world.profile.load()
        let model = ClientMergeViewModel(keptID: kept.id, vault: world.vault, profile: world.profile)
        await model.load()

        model.searchText = "98123"
        #expect(model.results.map(\.name) == ["Ana C."])

        model.searchText = "bridal"
        #expect(model.results.map(\.name) == ["Zoe"])
    }

    @Test("With no other profile the sheet says there is no one to merge with")
    func noCandidates() async throws {
        let kept = makeListedClient(name: "Ana Costa")
        let world = try await makeWorld(with: [kept])
        let model = ClientMergeViewModel(keptID: kept.id, vault: world.vault, profile: world.profile)

        await model.load()

        #expect(model.hasNoCandidates)
    }

    @Test("Merging moves the other profile's records to the kept one and deletes the other")
    func merges() async throws {
        let kept = makeListedClient(name: "Ana Costa")
        let other = makeListedClient(name: "Ana C.")
        let world = try await makeWorld(with: [kept, other])
        try await world.repository.save(makeAppointment(clientID: other.id, daysFromNow: -10))
        let model = ClientMergeViewModel(keptID: kept.id, vault: world.vault, profile: world.profile)
        await model.load()
        model.chosen = other

        await model.mergeAsync(other)

        #expect(model.didMerge && model.errorMessage == nil)
        #expect(try await world.repository.client(id: other.id) == nil)
        #expect(try await world.repository.appointments(for: kept.id).count == 1)
        #expect(try await world.repository.registrationLedger().count == 2, "a merge never frees a registration")
    }

    @Test("A merge that cannot happen is an error and changes nothing")
    func mergeFails() async throws {
        let kept = makeListedClient(name: "Ana Costa")
        let world = try await makeWorld(with: [kept])
        let model = ClientMergeViewModel(keptID: kept.id, vault: world.vault, profile: world.profile)
        await model.load()

        await model.mergeAsync(makeListedClient(name: "Not in the vault"))

        #expect(!model.didMerge && model.errorMessage != nil)
        #expect(try await world.repository.allClients().count == 1)
        model.dismissError()
        #expect(model.errorMessage == nil)
    }

    @Test("A vault that cannot be opened is an error")
    func unavailable() async {
        let (vault, profile) = ClientsWorld.unavailable()
        let model = ClientMergeViewModel(keptID: UUID(), vault: vault, profile: profile)

        await model.load()

        #expect(model.errorMessage != nil && !model.isLoading && !model.hasNoCandidates)
    }
}
