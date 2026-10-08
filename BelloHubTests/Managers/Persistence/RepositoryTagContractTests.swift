//
//  RepositoryTagContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// What deleting and reordering tags must do in every vault implementation. Run against both flavors, like the other
/// contract suites, so the in-memory repository can never promise something the real one does not.
@Suite("Repository contract: tags and record fields", .serialized)
struct RepositoryTagContractTests {
    private let fixture = ContractFixture()

    /// `BelloHub.Tag`, because Swift Testing has a `Tag` of its own.
    private func makeTag(_ name: String, position: Int) -> BelloHub.Tag {
        BelloHub.Tag(id: UUID(), name: name, colorToken: "rose", position: position)
    }

    private func client(_ name: String, tags: [BelloHub.Tag], note: String? = nil) -> Client {
        Client(
            name: name, phoneE164: nil, tagIDs: tags.map(\.id), createdAt: fixture.clock.now, importantNote: note,
            allergies: note.map { _ in ["fragrance"] } ?? []
        )
    }

    // MARK: - Deleting a tag

    @Test("Deleting a tag takes it off every client that has it and deletes no client",
          arguments: RepositoryFlavor.allCases)
    func deleteRemovesFromClients(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let vip = makeTag("VIP", position: 0)
        let bridal = makeTag("Bridal", position: 1)
        try await repository.save([vip, bridal])
        let ana = client("Ana", tags: [vip, bridal], note: "Sentinel-NOTE")
        let bia = client("Bia", tags: [vip])
        let cris = client("Cris", tags: [bridal])
        let dani = client("Dani", tags: [])
        for each in [ana, bia, cris, dani] { try await repository.save(each) }
        fixture.clock.advance(by: 60)

        let affected = try await repository.deleteTagRemovingFromClients(id: vip.id)

        #expect(affected == 2)
        #expect(try await repository.tags().map(\.id) == [bridal.id])
        #expect(try await repository.client(id: ana.id)?.tagIDs == [bridal.id])
        #expect(try await repository.client(id: bia.id)?.tagIDs == [])
        #expect(try await repository.client(id: cris.id)?.tagIDs == [bridal.id])
        #expect(try await repository.client(id: dani.id)?.tagIDs == [])
        // Nobody was deleted, and the sealed fields of a client that was rewritten are intact.
        #expect(try await repository.allClients().count == 4)
        let rewritten = try #require(try await repository.client(id: ana.id))
        #expect(rewritten.importantNote == "Sentinel-NOTE" && rewritten.allergies == ["fragrance"])
        #expect(rewritten.name == "Ana" && rewritten.updatedAt == fixture.clock.now)
    }

    @Test("Removing a tag from clients is not a registration: the ledger does not move",
          arguments: RepositoryFlavor.allCases)
    func deleteLeavesTheLedgerAlone(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let vip = makeTag("VIP", position: 0)
        try await repository.save(vip)
        let ana = client("Ana", tags: [vip])
        try await repository.save(ana)
        let before = try await repository.registrationLedger()

        try await repository.deleteTagRemovingFromClients(id: vip.id)

        #expect(try await repository.registrationLedger() == before)
        #expect(before.map(\.clientID) == [ana.id])
    }

    @Test("A tag nobody has is deleted and counts zero; an id that does not exist changes nothing",
          arguments: RepositoryFlavor.allCases)
    func deleteUnusedAndUnknown(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let unused = makeTag("Regular", position: 0)
        let kept = makeTag("VIP", position: 1)
        try await repository.save([unused, kept])
        let ana = client("Ana", tags: [kept])
        try await repository.save(ana)

        #expect(try await repository.deleteTagRemovingFromClients(id: unused.id) == 0)
        #expect(try await repository.tags().map(\.id) == [kept.id])
        #expect(try await repository.deleteTagRemovingFromClients(id: UUID()) == 0)
        #expect(try await repository.tags().map(\.id) == [kept.id])
        #expect(try await repository.client(id: ana.id)?.tagIDs == [kept.id])
    }

    @Test("Deleting the same tag twice is safe", arguments: RepositoryFlavor.allCases)
    func deleteIsIdempotent(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let vip = makeTag("VIP", position: 0)
        try await repository.save(vip)
        try await repository.save(client("Ana", tags: [vip]))

        #expect(try await repository.deleteTagRemovingFromClients(id: vip.id) == 1)
        #expect(try await repository.deleteTagRemovingFromClients(id: vip.id) == 0)
    }

    @Test("The plain delete removes only the tag and leaves the clients as they were",
          arguments: RepositoryFlavor.allCases)
    func plainDeleteLeavesClients(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let vip = makeTag("VIP", position: 0)
        try await repository.save(vip)
        let ana = client("Ana", tags: [vip])
        try await repository.save(ana)

        try await repository.deleteTag(id: vip.id)

        #expect(try await repository.tags().isEmpty)
        #expect(try await repository.client(id: ana.id)?.tagIDs == [vip.id])
    }

    // MARK: - Saving several tags

    @Test("Several tags are stored together and listed by their new positions", arguments: RepositoryFlavor.allCases)
    func saveSeveralTags(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let first = makeTag("A", position: 0)
        let second = makeTag("B", position: 1)
        let third = makeTag("C", position: 2)
        try await repository.save([first, second, third])
        #expect(try await repository.tags().map(\.name) == ["A", "B", "C"])

        var moved = [third, first, second]
        for index in moved.indices { moved[index].position = index }
        try await repository.save(moved)

        #expect(try await repository.tags().map(\.name) == ["C", "A", "B"])
        #expect(try await repository.tags().map(\.position) == [0, 1, 2])
    }

    @Test("Saving no tags does nothing", arguments: RepositoryFlavor.allCases)
    func saveNoTags(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        try await repository.save([BelloHub.Tag]())
        #expect(try await repository.tags().isEmpty)
    }

    // MARK: - The record template with fields of her own

    @Test("A template with fields of her own keeps their kind, options, unit and order",
          arguments: RepositoryFlavor.allCases)
    func templateWithCustomFields(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let template = RecordTemplate(
            fields: [
                RecordFieldSetting(profession: .esthetician, key: "est.skin", isOn: true),
                RecordFieldSetting(
                    profession: .esthetician, key: "custom-a", customName: "Finish", isOn: true, kind: .choice,
                    options: ["Matte", "Dewy"]
                ),
                RecordFieldSetting(
                    profession: .esthetician, key: "custom-b", customName: "Length", isOn: false, kind: .number,
                    unit: "mm"
                ),
                RecordFieldSetting(
                    profession: .esthetician, key: "custom-c", customName: "Patch test", isOn: true, kind: .yesNo
                )
            ],
            intake: [IntakeSetting(profession: .esthetician, item: .patchTestLog, isOn: true)],
            updatedAt: fixture.clock.now
        )

        try await repository.save(template)

        let stored = try #require(try await repository.recordTemplate())
        #expect(stored.fields == template.fields)
        #expect(stored.fields.map(\.kind) == [.text, .choice, .number, .yesNo])
        #expect(stored.fields[1].options == ["Matte", "Dewy"] && stored.fields[2].unit == "mm")
        #expect(stored.intake == template.intake)
    }
}
