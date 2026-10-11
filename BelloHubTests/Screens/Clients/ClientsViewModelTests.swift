//
//  ClientsViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("ClientsViewModel", .serialized)
struct ClientsViewModelTests {
    private func makeModel(_ world: ClientsWorld) -> ClientsViewModel {
        ClientsViewModel(vault: world.vault, profile: world.profile, now: { TestClock.now })
    }

    private func loaded(_ model: ClientsViewModel) async -> Bool {
        await Wait.untilMain { !model.isLoading }
    }

    // MARK: - Loading

    @Test("The list loads in reading order, with a loading state until then")
    func loadsSortedClients() async throws {
        let world = try await ClientsWorld.make()
        for name in ["Zoe", "María", "Ana"] { try await world.repository.save(makeListedClient(name: name)) }
        let model = makeModel(world)
        #expect(model.isLoading)

        model.startListening()
        defer { model.stopListening() }

        #expect(await loaded(model))
        #expect(model.visible.map(\.client.name) == ["Ana", "María", "Zoe"])
        #expect(model.count == 3)
        #expect(!model.isEmpty && model.errorMessage == nil)
    }

    @Test("An empty vault is an empty list, not a loading screen and not an error")
    func emptyVault() async throws {
        let world = try await ClientsWorld.make()
        let model = makeModel(world)

        model.startListening()
        defer { model.stopListening() }

        #expect(await loaded(model))
        #expect(model.isEmpty && model.visible.isEmpty && model.errorMessage == nil)
    }

    @Test("A vault that cannot be opened is an error, not an empty list")
    func unavailableVault() async {
        let (vault, profile) = ClientsWorld.unavailable()
        let model = ClientsViewModel(vault: vault, profile: profile, now: { TestClock.now })

        model.startListening()

        #expect(!model.isLoading)
        #expect(model.errorMessage != nil)
    }

    @Test("The list follows the vault: a saved client appears, an archived one leaves and a deleted one goes")
    func followsTheVault() async throws {
        let world = try await ClientsWorld.make()
        let model = makeModel(world)
        model.startListening()
        defer { model.stopListening() }
        #expect(await loaded(model))

        let ana = makeListedClient(name: "Ana")
        try await world.repository.save(ana)
        #expect(await Wait.untilMain { model.visible.map(\.client.name) == ["Ana"] })

        var archived = ana
        archived.isArchived = true
        try await world.repository.save(archived)
        #expect(await Wait.untilMain { model.visible.isEmpty && model.list.hasArchived })

        try await world.repository.deleteClient(id: ana.id)
        #expect(await Wait.untilMain { model.isEmpty })
    }

    @Test("A new appointment changes the entries: a client with a booking is no longer 'no visit yet'")
    func followsAppointments() async throws {
        let world = try await ClientsWorld.make()
        let ana = makeListedClient(name: "Ana")
        try await world.repository.save(ana)
        let model = makeModel(world)
        model.startListening()
        defer { model.stopListening() }
        #expect(await loaded(model))
        #expect(model.visible.first?.summary == .noVisitsYet)

        let booked = makeAppointment(clientID: ana.id, daysFromNow: 4, status: .booked, serviceName: "Glow Facial")
        try await world.repository.save(booked)

        let expected = ClientRowSummary.booked(service: "Glow Facial", date: booked.startsAt)
        #expect(await Wait.untilMain { model.visible.first?.summary == expected })
    }

    // MARK: - Chips and search

    @Test("A chip narrows the list and the count follows; All brings everyone back")
    func chips() async throws {
        let world = try await ClientsWorld.make()
        let sensitive = try #require(world.tags.first)
        try await world.repository.save(makeListedClient(name: "Ana", tagIDs: [sensitive.id]))
        try await world.repository.save(makeListedClient(name: "Beatriz"))
        let model = makeModel(world)
        model.startListening()
        defer { model.stopListening() }
        #expect(await loaded(model))

        model.select(.tag(sensitive.id))
        #expect(model.visible.map(\.client.name) == ["Ana"] && model.count == 1)

        model.select(.all)
        #expect(model.count == 2)
    }

    @Test("The chips are the fixed ones and her tags, with Archived only once someone is archived")
    func chipList() async throws {
        let world = try await ClientsWorld.make()
        let model = makeModel(world)
        model.startListening()
        defer { model.stopListening() }
        #expect(await loaded(model))

        let fixed: [ClientListFilter] = [.all, .dueToReturn, .cancelsOften, .new]
        #expect(model.chips == fixed + world.tags.map { ClientListFilter.tag($0.id) })

        try await world.repository.save(makeListedClient(name: "Old", isArchived: true))
        #expect(await Wait.untilMain { model.chips.last == .archived })
    }

    @Test("Search narrows by name, and a search with no result says so while the list is not empty")
    func search() async throws {
        let world = try await ClientsWorld.make()
        try await world.repository.save(makeListedClient(name: "María José"))
        try await world.repository.save(makeListedClient(name: "Beatriz"))
        let model = makeModel(world)
        model.startListening()
        defer { model.stopListening() }
        #expect(await loaded(model))

        model.setSearchText("maria")
        #expect(model.visible.map(\.client.name) == ["María José"] && model.isSearching)

        model.setSearchText("nobody")
        #expect(model.visible.isEmpty && model.hasNoMatches && !model.isEmpty)

        model.setSearchText("")
        #expect(model.count == 2 && !model.isSearching)
    }

    @Test("The haven't-been-back strip shows on the plain list only")
    func winBackStrip() async throws {
        let world = try await ClientsWorld.make()
        let away = makeListedClient(name: "Away")
        try await world.repository.save(away)
        try await world.repository.save(makeAppointment(clientID: away.id, daysFromNow: -75))
        let model = makeModel(world)
        model.startListening()
        defer { model.stopListening() }
        #expect(await loaded(model))
        #expect(model.winBackCount == 1)

        model.setSearchText("away")
        #expect(model.winBackCount == 0)

        model.setSearchText("")
        model.select(.new)
        #expect(model.winBackCount == 0)
    }

    @Test("A chip whose tag was deleted falls back to everyone")
    func deletedTagResetsTheChip() async throws {
        let world = try await ClientsWorld.make()
        let tag = try #require(world.tags.first)
        try await world.repository.save(makeListedClient(name: "Ana", tagIDs: [tag.id]))
        let model = makeModel(world)
        model.startListening()
        defer { model.stopListening() }
        #expect(await loaded(model))
        model.select(.tag(tag.id))

        try await world.repository.deleteTag(id: tag.id)
        await world.profile.load()
        model.tagsChanged()

        #expect(model.filter == .all && model.count == 1)
    }

    // MARK: - Refresh and stop

    @Test("Refreshing reads the vault again, and stopping forgets everything")
    func refreshAndStop() async throws {
        let world = try await ClientsWorld.make()
        let model = makeModel(world)
        try await world.repository.save(makeListedClient(name: "Ana"))

        await model.refreshAsync()
        #expect(model.count == 1 && !model.isLoading)

        model.stopListening()
        #expect(model.isLoading && model.visible.isEmpty && model.isEmpty)
    }
}
