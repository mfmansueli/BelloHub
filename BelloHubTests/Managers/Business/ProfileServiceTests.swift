//
//  ProfileServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

private typealias Fixtures = TagsRecordFixtures

@MainActor
@Suite("ProfileService")
struct ProfileServiceTests {
    private struct Rig {
        let profile: ProfileService
        let repository: any ClientRecordRepository
        let clock: MutableClock
    }

    /// A service over the in-memory vault with a finished setup loaded.
    private func makeRig() async throws -> Rig {
        let clock = MutableClock()
        let repository = InMemoryClientRecordRepository(clock: { clock.now })
        let profile = ProfileService(vault: VaultService(repository: repository))
        try await profile.saveOnboarding(Fixtures.result())
        return Rig(profile: profile, repository: repository, clock: clock)
    }

    /// A service over a repository that can be told to fail, with a finished setup loaded.
    private func makeFlakyRig() async -> (profile: ProfileService, repository: FakeBusinessRepository) {
        let repository = FakeBusinessRepository()
        await repository.seed(Fixtures.result())
        let profile = ProfileService(repository: repository)
        await profile.load()
        return (profile, repository)
    }

    // MARK: - Tags

    @Test("A saved tag joins the list in order, and saving it again replaces it instead of repeating it")
    func saveTag() async throws {
        let rig = try await makeRig()
        #expect(rig.profile.tags.map(\.name) == ["VIP", "Sensitive Skin"])

        var bridal = Fixtures.tag("Bridal", color: "sage", position: 5)
        try await rig.profile.saveTag(bridal)
        #expect(rig.profile.tags.map(\.name) == ["VIP", "Sensitive Skin", "Bridal"])

        bridal.name = "Bride"
        bridal.position = 0
        try await rig.profile.saveTag(bridal)
        #expect(rig.profile.tags.map(\.name).sorted() == ["Bride", "Sensitive Skin", "VIP"])
        #expect(rig.profile.tags.count == 3)
        #expect(try await rig.repository.tags().count == 3)
    }

    @Test("Several tags are saved together and listed in their new order")
    func saveTags() async throws {
        let rig = try await makeRig()
        var reordered = rig.profile.tags
        reordered[0].position = 1
        reordered[1].position = 0

        try await rig.profile.saveTags(reordered)

        #expect(rig.profile.tags.map(\.name) == ["Sensitive Skin", "VIP"])
        #expect(try await rig.repository.tags().map(\.name) == ["Sensitive Skin", "VIP"])
    }

    @Test("Deleting a tag removes it from the list and from every client that has it, and keeps the clients")
    func deleteTag() async throws {
        let rig = try await makeRig()
        let vip = try #require(rig.profile.tags.first { $0.name == "VIP" })
        let sensitive = try #require(rig.profile.tags.first { $0.name == "Sensitive Skin" })
        let ana = Fixtures.client("Ana", tags: [vip, sensitive])
        let bia = Fixtures.client("Bia", tags: [vip])
        let cris = Fixtures.client("Cris", tags: [sensitive])
        for client in [ana, bia, cris] { try await rig.repository.save(client) }

        let affected = try await rig.profile.deleteTag(id: vip.id)

        #expect(affected == 2)
        #expect(rig.profile.tags.map(\.name) == ["Sensitive Skin"])
        #expect(try await rig.repository.client(id: ana.id)?.tagIDs == [sensitive.id])
        #expect(try await rig.repository.client(id: bia.id)?.tagIDs == [])
        #expect(try await rig.repository.client(id: cris.id)?.tagIDs == [sensitive.id])
        #expect(try await rig.repository.allClients().count == 3)
    }

    @Test("A tag another screen saved through the repository shows up after a reload")
    func reloadTags() async throws {
        let rig = try await makeRig()
        try await rig.repository.save(Fixtures.tag("Added inline", position: 7))
        #expect(rig.profile.tags.count == 2)

        try await rig.profile.reloadTags()

        #expect(rig.profile.tags.map(\.name) == ["VIP", "Sensitive Skin", "Added inline"])
    }

    // MARK: - Record template

    @Test("A saved template becomes the current one, with the time the vault stamped on it")
    func saveTemplate() async throws {
        let rig = try await makeRig()
        var template = try #require(rig.profile.template)
        let key = try #require(template.fields.first { !$0.isOn }?.key)
        template.fields = template.fields.map { field in
            var switched = field
            if field.key == key { switched.isOn = true }
            return switched
        }
        rig.clock.advance(by: 3_600)

        try await rig.profile.saveTemplate(template)

        #expect(rig.profile.template?.enabledKeys(for: .esthetician) == ["est.skin", "est.technique"])
        #expect(rig.profile.template?.updatedAt == rig.clock.now)
        #expect(try await rig.repository.recordTemplate() == rig.profile.template)
    }

    @Test("A template another screen or device changed shows up after a reload")
    func reloadTemplate() async throws {
        let rig = try await makeRig()
        var changed = try #require(rig.profile.template)
        changed.fields.append(
            RecordFieldSetting(profession: .esthetician, key: "custom-1", customName: "Mood", isOn: true)
        )
        try await rig.repository.save(changed)
        #expect(rig.profile.template?.fields.count == 2)

        try await rig.profile.reloadTemplate()

        #expect(rig.profile.template?.fields.count == 3)
    }

    // MARK: - When the vault says no

    @Test("A write the vault refuses leaves the tags and the template as they were")
    func failedWritesChangeNothing() async throws {
        let (profile, repository) = await makeFlakyRig()
        let tagsBefore = profile.tags
        let templateBefore = try #require(profile.template)
        var changed = templateBefore
        changed.fields[0].isOn.toggle()
        await repository.setFailsWrites(true)

        let failure = FakeBusinessRepository.WriteFailure.self
        await #expect(throws: failure) { try await profile.saveTag(Fixtures.tag("New")) }
        await #expect(throws: failure) { try await profile.saveTags(tagsBefore) }
        await #expect(throws: failure) { try await profile.deleteTag(id: tagsBefore[0].id) }
        await #expect(throws: failure) { try await profile.saveTemplate(changed) }

        #expect(profile.tags == tagsBefore)
        #expect(profile.template == templateBefore)
        #expect(await repository.storedTags() == tagsBefore)
        #expect(await repository.storedRecordTemplate() == templateBefore)
    }

    @Test("Without a vault every edit says so, and loading is a quiet no-op")
    func unavailableVault() async {
        let profile = ProfileService(vault: VaultService(repository: nil))

        await profile.load()
        #expect(profile.tags.isEmpty && profile.template == nil && profile.profile == nil)
        await #expect(throws: VaultRepositoryError.unavailable) { try await profile.reloadTags() }
        await #expect(throws: VaultRepositoryError.unavailable) { try await profile.saveTag(Fixtures.tag("New")) }
        await #expect(throws: VaultRepositoryError.unavailable) { try await profile.saveTags([]) }
        await #expect(throws: VaultRepositoryError.unavailable) { try await profile.deleteTag(id: UUID()) }
        await #expect(throws: VaultRepositoryError.unavailable) { try await profile.reloadTemplate() }
        let template = RecordTemplate(fields: [], intake: [], updatedAt: TestClock.now)
        await #expect(throws: VaultRepositoryError.unavailable) { try await profile.saveTemplate(template) }
    }

    @Test("Clearing forgets the profile, the template and the tags")
    func clear() async throws {
        let rig = try await makeRig()
        #expect(rig.profile.profile != nil && rig.profile.template != nil && !rig.profile.tags.isEmpty)

        rig.profile.clear()

        #expect(rig.profile.profile == nil && rig.profile.template == nil && rig.profile.tags.isEmpty)
        await rig.profile.load()
        #expect(rig.profile.tags.count == 2 && rig.profile.template != nil)
    }
}
