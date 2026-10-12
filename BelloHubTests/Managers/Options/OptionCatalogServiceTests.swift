//
//  OptionCatalogServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("OptionCatalogService", .serialized)
struct OptionCatalogServiceTests {
    private func makeService() -> (OptionCatalogService, any ClientRecordRepository) {
        let repository: any ClientRecordRepository = InMemoryClientRecordRepository(clock: { TestClock.now })
        let service = OptionCatalogService(vault: VaultService(repository: repository), now: { TestClock.now })
        return (service, repository)
    }

    @Test("The same name twice is one option; each list keeps its own words")
    func noDuplicates() async throws {
        let (service, repository) = makeService()
        let first = try await service.add("Curl C", to: .technique)
        let again = try await service.add("  curl c ", to: .technique)
        try await service.add("Curl C", to: .preference)

        #expect(first.id == again.id)
        #expect(service.names(in: .technique) == ["Curl C"])
        #expect(service.names(in: .preference) == ["Curl C"])
        #expect(try await repository.savedOptions().count == 2)
    }

    @Test("Archiving hides an option from suggestions and keeps it; adding it again restores it")
    func archiveAndRestore() async throws {
        let (service, _) = makeService()
        let option = try await service.add("Lifting", to: .technique)
        try await service.setArchived(option.id, true)
        #expect(service.names(in: .technique).isEmpty)
        #expect(service.options(in: .technique, includingArchived: true).map(\.isArchived) == [true])

        let restored = try await service.add("lifting", to: .technique)
        #expect(restored.id == option.id)
        #expect(service.names(in: .technique) == ["Lifting"])
    }

    @Test("Renaming refuses a name that already exists in the list, and reorder keeps her order")
    func renameAndMove() async throws {
        let (service, _) = makeService()
        let peel = try await service.add("Peel", to: .technique)
        try await service.add("Mask", to: .technique)
        await #expect(throws: OptionCatalogService.Problem.duplicate(existing: "Mask")) {
            try await service.rename(peel.id, to: "MASK")
        }
        try await service.rename(peel.id, to: "Gentle peel")
        try await service.move(in: .technique, from: IndexSet(integer: 1), to: 0)

        #expect(service.names(in: .technique) == ["Mask", "Gentle peel"])
    }

    @Test("Options come back after a reload, from the vault")
    func persisted() async throws {
        let (service, repository) = makeService()
        try await service.add("Fragrance-free", to: .preference)
        let fresh = OptionCatalogService(vault: VaultService(repository: repository))
        await fresh.loadIfNeeded()

        #expect(fresh.names(in: .preference) == ["Fragrance-free"])
    }
}
