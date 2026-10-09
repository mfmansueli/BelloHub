//
//  ProductsViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("ProductsViewModel")
struct ProductsViewModelTests {
    private func products(_ names: String...) -> [Product] {
        names.enumerated().map { Product(name: $1, category: .serum, position: $0) }
    }

    private func draft(_ name: String, brand: String = "", shared: Bool = false) -> ProductDraft {
        var draft = ProductDraft()
        draft.name = name
        draft.brand = brand
        draft.sharedWithClient = shared
        return draft
    }

    @Test("Loading reads the products in order; with none the empty state shows")
    func load() async {
        let repository = FakeCatalogRepository()
        let model = ProductsViewModel(repository: repository)
        await model.loadAsync()
        #expect(model.showsEmptyState)

        await repository.seed(products: products("B", "A"))
        await model.loadAsync()
        #expect(model.products.map(\.name) == ["B", "A"] && !model.showsEmptyState)
    }

    @Test("A failed read says so and shows no empty state")
    func readFailure() async {
        let repository = FakeCatalogRepository()
        await repository.setFailsReads(true)
        let model = ProductsViewModel(repository: repository)
        await model.loadAsync()
        #expect(model.errorMessage != nil && !model.showsEmptyState)
    }

    @Test("Adding stores a private product unless she shares it")
    func add() async throws {
        let repository = FakeCatalogRepository()
        let model = ProductsViewModel(repository: repository)
        await model.loadAsync()

        await model.save(draft("Calming serum", brand: "Acme"), editing: nil)
        await model.save(draft("Gentle cleanser", shared: true), editing: nil)

        let stored = await repository.storedProducts()
        #expect(stored.map(\.name) == ["Calming serum", "Gentle cleanser"])
        #expect(stored.map(\.sharedWithClient) == [false, true] && stored.map(\.position) == [0, 1])
    }

    @Test("The chip shares or withholds a product at once, and only that setting changes")
    func setShared() async throws {
        let repository = FakeCatalogRepository()
        let serum = Product(name: "Serum", brand: "Acme", category: .serum, note: "Calm", position: 0)
        await repository.seed(products: [serum])
        let model = ProductsViewModel(repository: repository)
        await model.loadAsync()

        await model.setSharedAsync(true, for: serum)

        let stored = try #require(await repository.storedProducts().first)
        #expect(stored.sharedWithClient && stored.brand == "Acme" && stored.note == "Calm")
        #expect(model.products.first?.sharedWithClient == true)

        await model.setSharedAsync(false, for: stored)
        #expect(model.products.first?.sharedWithClient == false)
    }

    @Test("A draft with an issue is refused and nothing is written")
    func refused() async {
        let repository = FakeCatalogRepository()
        await repository.seed(products: products("Serum"))
        let model = ProductsViewModel(repository: repository)
        await model.loadAsync()

        #expect(await model.save(draft("serum"), editing: nil) == false)
        #expect(await model.save(draft(""), editing: nil) == false)
        #expect(await repository.writeCount == 0)
        #expect(model.issues(in: draft("serum"), editing: nil) == [.nameTaken])
    }

    @Test("A failed write leaves the list as it was and says so")
    func writeFailure() async {
        let repository = FakeCatalogRepository()
        let list = products("Serum")
        await repository.seed(products: list)
        let model = ProductsViewModel(repository: repository)
        await model.loadAsync()
        await repository.setFailsWrites(true)

        await model.setSharedAsync(true, for: list[0])
        #expect(model.products.first?.sharedWithClient == false && model.saveErrorMessage != nil)
        #expect(await model.save(draft("New"), editing: nil) == false)
        #expect(await model.delete(list[0]) == false)
        #expect(model.products.count == 1)
    }

    @Test("Deleting removes only that product")
    func delete() async throws {
        let repository = FakeCatalogRepository()
        await repository.seed(products: products("A", "B"))
        let model = ProductsViewModel(repository: repository)
        await model.loadAsync()

        await model.delete(try #require(model.products.first))

        let stored = await repository.storedProducts().map(\.name)
        #expect(model.products.map(\.name) == ["B"] && stored == ["B"])
    }
}
