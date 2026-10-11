//
//  AddOnsViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("AddOnsViewModel")
struct AddOnsViewModelTests {
    private let english = Locale(identifier: "en_US")

    private func addOns(_ names: String...) -> [AddOn] {
        names.enumerated().map {
            AddOn(id: UUID(), name: $1, minutes: 15, priceAmount: nil, isOffered: true, position: $0)
        }
    }

    private func draft(_ name: String, price: String = "") -> AddOnDraft {
        var draft = AddOnDraft()
        draft.name = name
        draft.priceText = price
        return draft
    }

    private func makeModel(_ repository: FakeCatalogRepository) -> AddOnsViewModel {
        AddOnsViewModel(repository: repository, locale: english)
    }

    @Test("Loading reads the add-ons in order; with none the empty state shows")
    func load() async {
        let repository = FakeCatalogRepository()
        let model = makeModel(repository)
        await model.loadAsync()
        #expect(model.showsEmptyState && model.hasLoaded)

        await repository.seed(addOns: addOns("B", "A"))
        await model.loadAsync()
        #expect(model.addOns.map(\.name) == ["B", "A"] && !model.showsEmptyState)
    }

    @Test("A failed read says so and shows no empty state")
    func readFailure() async {
        let repository = FakeCatalogRepository()
        await repository.setFailsReads(true)
        let model = makeModel(repository)
        await model.loadAsync()
        #expect(model.errorMessage != nil && !model.showsEmptyState)
    }

    @Test("Adding stores the add-on with its time and optional price after the last one")
    func add() async throws {
        let repository = FakeCatalogRepository()
        await repository.seed(addOns: addOns("A"))
        let model = makeModel(repository)
        await model.loadAsync()
        var form = draft("LED light", price: "25")
        form.minutes = 20

        let saved = await model.save(form, editing: nil)

        #expect(saved)
        let stored = try #require(await repository.storedAddOns().last)
        #expect(stored.name == "LED light" && stored.minutes == 20 && stored.priceAmount == 25 && stored.position == 1)
    }

    @Test("A name that is taken or empty is refused and nothing is written")
    func refused() async {
        let repository = FakeCatalogRepository()
        await repository.seed(addOns: addOns("LED light"))
        let model = makeModel(repository)
        await model.loadAsync()

        #expect(await model.save(draft("led light"), editing: nil) == false)
        #expect(await model.save(draft(""), editing: nil) == false)
        #expect(await repository.writeCount == 0)
        #expect(model.issues(in: draft("led light"), editing: nil) == [.nameTaken])
    }

    @Test("The switch offers or withdraws an add-on at once and the preview follows")
    func toggle() async {
        let repository = FakeCatalogRepository()
        let list = addOns("A", "B")
        await repository.seed(addOns: list)
        let model = makeModel(repository)
        await model.loadAsync()
        #expect(model.offered.map(\.name) == ["A", "B"])

        await model.setOfferedAsync(false, for: list[0])

        #expect(model.offered.map(\.name) == ["B"])
        #expect(await repository.storedAddOns().first?.isOffered == false)
    }

    @Test("A failed write leaves the list as it was and says so")
    func writeFailure() async {
        let repository = FakeCatalogRepository()
        let list = addOns("A")
        await repository.seed(addOns: list)
        let model = makeModel(repository)
        await model.loadAsync()
        await repository.setFailsWrites(true)

        await model.setOfferedAsync(false, for: list[0])
        #expect(model.offered.count == 1 && model.saveErrorMessage != nil)

        let saved = await model.save(draft("New"), editing: nil)
        #expect(!saved && model.addOns.count == 1)
        let deleted = await model.delete(list[0])
        #expect(!deleted && model.addOns.count == 1)
    }

    @Test("Deleting removes only that add-on")
    func delete() async throws {
        let repository = FakeCatalogRepository()
        await repository.seed(addOns: addOns("A", "B"))
        let model = makeModel(repository)
        await model.loadAsync()

        await model.delete(try #require(model.addOns.first))

        let stored = await repository.storedAddOns().map(\.name)
        #expect(model.addOns.map(\.name) == ["B"] && stored == ["B"])
    }

    @Test("A drag renumbers the add-ons and writes them in one write; a failure puts them back")
    func move() async {
        let repository = FakeCatalogRepository()
        await repository.seed(addOns: addOns("A", "B", "C"))
        let model = makeModel(repository)
        await model.loadAsync()

        await model.moveAsync(from: IndexSet(integer: 0), to: 3)
        let bulk = await repository.bulkWriteCount
        #expect(model.addOns.map(\.name) == ["B", "C", "A"] && bulk == 1)

        await repository.setFailsWrites(true)
        await model.moveAsync(from: IndexSet(integer: 0), to: 3)
        #expect(model.addOns.map(\.name) == ["B", "C", "A"] && model.saveErrorMessage != nil)
    }
}
