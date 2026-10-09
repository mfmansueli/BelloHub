//
//  ServicesViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("ServicesViewModel")
struct ServicesViewModelTests {
    private let english = Locale(identifier: "en_US")

    private func makeModel(
        _ repository: FakeCatalogRepository, catalog: FakeHealthFormCatalogProvider = FakeHealthFormCatalogProvider()
    ) -> ServicesViewModel {
        ServicesViewModel(repository: repository, locale: english, catalogProvider: catalog)
    }

    private func services(_ names: String...) -> [Service] {
        names.enumerated().map { Service(name: $1, category: "Facial", durationMinutes: 60, position: $0) }
    }

    private func draft(_ name: String, price: String = "") -> ServiceDraft {
        var draft = ServiceDraft()
        draft.name = name
        draft.priceText = price
        draft.category = "Facial"
        return draft
    }

    // MARK: - Loading

    @Test("Loading reads the services in order and clears the skeleton")
    func load() async {
        let repository = FakeCatalogRepository()
        await repository.seed(services: services("B", "A"))
        let model = makeModel(repository)
        #expect(!model.hasLoaded && !model.showsEmptyState)

        await model.loadAsync()

        #expect(model.services.map(\.name) == ["B", "A"], "by position")
        #expect(model.hasLoaded && !model.isLoading && model.errorMessage == nil)
        #expect(!model.showsEmptyState && !model.showsSkeleton)
    }

    @Test("With no services the empty state shows once the read is done")
    func emptyState() async {
        let model = makeModel(FakeCatalogRepository())
        await model.loadAsync()
        #expect(model.showsEmptyState)
    }

    @Test("A failed read says so, shows no empty state and keeps the earlier list")
    func readFailure() async {
        let repository = FakeCatalogRepository()
        await repository.seed(services: services("A"))
        let model = makeModel(repository)
        await model.loadAsync()
        await repository.setFailsReads(true)

        await model.loadAsync()

        #expect(model.errorMessage != nil && !model.showsEmptyState)
        #expect(model.services.map(\.name) == ["A"])
    }

    @Test("Without a vault the screen reports the failure instead of an empty list")
    func noVault() async {
        let model = ServicesViewModel(repository: nil, locale: english)
        await model.loadAsync()
        #expect(model.errorMessage != nil && !model.showsEmptyState)
    }

    // MARK: - Adding and editing

    @Test("A new service starts with the category most services use and is stored after the last")
    func addService() async throws {
        let repository = FakeCatalogRepository()
        await repository.seed(services: services("A", "B"))
        let model = makeModel(repository)
        await model.loadAsync()
        #expect(model.newDraft().category == "Facial")

        let saved = await model.save(draft("Brow Lift", price: "45"), editing: nil)

        #expect(saved)
        #expect(model.services.map(\.name) == ["A", "B", "Brow Lift"])
        let stored = try #require(await repository.storedServices().last)
        #expect(stored.name == "Brow Lift" && stored.position == 2 && stored.priceAmount == 45)
    }

    @Test("Contraindications and the patch-test setting are stored with the service")
    func settingsAreStored() async throws {
        let repository = FakeCatalogRepository()
        let model = makeModel(repository)
        await model.loadAsync()
        var form = draft("Chemical Peel")
        form.contraindications = ["pregnancy", "allergies.retinol"]
        form.requiresPatchTest = true
        form.patchTestHoursBefore = 72

        await model.save(form, editing: nil)

        let stored = try #require(await repository.storedServices().first)
        #expect(stored.contraindications == ["pregnancy", "allergies.retinol"])
        #expect(stored.requiresPatchTest && stored.patchTestHoursBefore == 72)
        // And the form reads them back.
        let reopened = model.draft(for: stored)
        #expect(reopened.contraindications == ["pregnancy", "allergies.retinol"] && reopened.requiresPatchTest)
    }

    @Test("Editing changes the service in place and keeps its position")
    func editService() async throws {
        let repository = FakeCatalogRepository()
        await repository.seed(services: services("A", "B", "C"))
        let model = makeModel(repository)
        await model.loadAsync()
        let target = try #require(model.services.first { $0.name == "B" })
        var form = model.draft(for: target)
        form.name = "B Deluxe"
        form.minutes = 90

        await model.save(form, editing: target)

        #expect(model.services.map(\.name) == ["A", "B Deluxe", "C"])
        #expect(model.services[1].durationMinutes == 90 && model.services[1].id == target.id)
    }

    @Test("A draft with an issue is refused and nothing is written")
    func refusedDraft() async {
        let repository = FakeCatalogRepository()
        await repository.seed(services: services("Glow Facial"))
        let model = makeModel(repository)
        await model.loadAsync()

        let taken = await model.save(draft("glow facial"), editing: nil)
        let empty = await model.save(draft(""), editing: nil)
        let badPrice = await model.save(draft("Peel", price: "abc"), editing: nil)

        #expect(!taken && !empty && !badPrice)
        #expect(await repository.writeCount == 0)
        #expect(model.issues(in: draft("glow facial"), editing: nil) == [.nameTaken])
    }

    @Test("A failed save says so and leaves the list as it was")
    func saveFailure() async {
        let repository = FakeCatalogRepository()
        let model = makeModel(repository)
        await model.loadAsync()
        await repository.setFailsWrites(true)

        let saved = await model.save(draft("Peel"), editing: nil)

        #expect(!saved && model.services.isEmpty && model.saveErrorMessage != nil)
        model.dismissSaveError()
        #expect(model.saveErrorMessage == nil)
    }

    // MARK: - Switching and deleting

    @Test("Switching a service off keeps everything else and survives a reload")
    func switchOff() async throws {
        let repository = FakeCatalogRepository()
        var glow = Service(name: "Glow", durationMinutes: 60, priceAmount: 70, contraindications: ["pregnancy"])
        glow.requiresPatchTest = true
        await repository.seed(services: [glow])
        let model = makeModel(repository)
        await model.loadAsync()

        await model.setActiveAsync(false, for: glow)

        let stored = try #require(await repository.storedServices().first)
        #expect(!stored.isActive)
        #expect(stored.priceAmount == 70 && stored.contraindications == ["pregnancy"] && stored.requiresPatchTest)
        #expect(model.services.first?.isActive == false)
    }

    @Test("A switch is never refused over an old duplicate name")
    func switchIgnoresNames() async {
        let repository = FakeCatalogRepository()
        let one = Service(name: "Glow", durationMinutes: 60, position: 0)
        let two = Service(name: "glow", durationMinutes: 60, position: 1)
        await repository.seed(services: [one, two])
        let model = makeModel(repository)
        await model.loadAsync()

        await model.setActiveAsync(false, for: two)

        #expect(model.services.last?.isActive == false)
    }

    @Test("Deleting removes the service and only that one")
    func delete() async throws {
        let repository = FakeCatalogRepository()
        await repository.seed(services: services("A", "B"))
        let model = makeModel(repository)
        await model.loadAsync()
        let first = try #require(model.services.first)

        let deleted = await model.delete(first)

        #expect(deleted && model.services.map(\.name) == ["B"])
        #expect(await repository.storedServices().map(\.name) == ["B"])
    }

    @Test("A failed delete keeps the service and says so")
    func deleteFailure() async throws {
        let repository = FakeCatalogRepository()
        await repository.seed(services: services("A"))
        let model = makeModel(repository)
        await model.loadAsync()
        await repository.setFailsWrites(true)

        let deleted = await model.delete(try #require(model.services.first))

        #expect(!deleted && model.services.count == 1 && model.saveErrorMessage != nil)
    }

    // MARK: - Reordering

    @Test("A drag renumbers the list and writes only what moved, in one write")
    func move() async {
        let repository = FakeCatalogRepository()
        await repository.seed(services: services("A", "B", "C", "D"))
        let model = makeModel(repository)
        await model.loadAsync()

        await model.moveAsync(from: IndexSet(integer: 1), to: 3)

        #expect(model.services.map(\.name) == ["A", "C", "B", "D"])
        #expect(await repository.storedServices().map(\.name) == ["A", "C", "B", "D"])
        let bulk = await repository.bulkWriteCount
        let writes = await repository.writeCount
        #expect(bulk == 1 && writes == 1)
    }

    @Test("A drag that changes nothing writes nothing")
    func moveNowhere() async {
        let repository = FakeCatalogRepository()
        await repository.seed(services: services("A", "B"))
        let model = makeModel(repository)
        await model.loadAsync()

        await model.moveAsync(from: IndexSet(integer: 0), to: 1)

        #expect(await repository.writeCount == 0)
    }

    @Test("A failed drag puts the list back and says so")
    func moveFailure() async {
        let repository = FakeCatalogRepository()
        await repository.seed(services: services("A", "B", "C"))
        let model = makeModel(repository)
        await model.loadAsync()
        await repository.setFailsWrites(true)

        await model.moveAsync(from: IndexSet(integer: 0), to: 3)

        #expect(model.services.map(\.name) == ["A", "B", "C"] && model.saveErrorMessage != nil)
        #expect(await repository.storedServices().map(\.name) == ["A", "B", "C"])
    }

    // MARK: - Contraindication options

    @Test("The picker's groups come from the catalog and are read once")
    func contraindicationOptions() {
        let model = makeModel(FakeCatalogRepository())
        #expect(model.contraindicationGroups.isEmpty)

        model.loadContraindicationOptions()

        let ids = model.contraindicationGroups.map(\.id)
        #expect(ids.first == ContraindicationOptions.aboutTheClientGroupID && ids.contains("allergies"))
        let before = model.contraindicationGroups
        model.loadContraindicationOptions()
        #expect(model.contraindicationGroups == before)
    }

    @Test("A catalog that cannot be read leaves the under-18 option so the form still works")
    func contraindicationOptionsWithoutCatalog() {
        let model = makeModel(FakeCatalogRepository(), catalog: FakeHealthFormCatalogProvider(fails: true))
        model.loadContraindicationOptions()
        #expect(model.contraindicationGroups.flatMap(\.options).map(\.token) == [ContraindicationMatcher.minorToken])
    }
}
