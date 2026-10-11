//
//  TagsViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

private typealias Fixtures = TagsRecordFixtures

@MainActor
@Suite("TagsViewModel")
struct TagsViewModelTests {
    private struct Rig {
        let model: TagsViewModel
        let profile: ProfileService
        let repository: any ClientRecordRepository
    }

    /// The view model over the in-memory vault. The tags are already in the profile service, as they are by the time
    /// the More tab shows; the model itself has not read anything yet.
    private func makeRig(withTags: Bool = true) async throws -> Rig {
        let repository = InMemoryClientRecordRepository(clock: { TestClock.now })
        let profile = ProfileService(vault: VaultService(repository: repository))
        try await profile.saveOnboarding(Fixtures.result(tagKeys: withTags ? ["est.vip", "est.sensitive"] : []))
        let model = TagsViewModel(profile: profile, clients: repository)
        return Rig(model: model, profile: profile, repository: repository)
    }

    /// `BelloHub.Tag`, because Swift Testing has a `Tag` of its own.
    private func tag(_ name: String, in rig: Rig) throws -> BelloHub.Tag {
        try #require(rig.model.tags.first { $0.name == name })
    }

    private func storedNames(_ rig: Rig) async -> [String]? {
        (try? await rig.repository.tags())?.map(\.name)
    }

    // MARK: - Reading

    @Test("Loading reads the tags and counts the clients that carry each one")
    func loadCounts() async throws {
        let rig = try await makeRig()
        let vip = try tag("VIP", in: rig)
        let sensitive = try tag("Sensitive Skin", in: rig)
        try await rig.repository.save(Fixtures.client("Ana", tags: [vip]))
        try await rig.repository.save(Fixtures.client("Bia", tags: [vip, sensitive]))
        try await rig.repository.save(Fixtures.client("Cris", tags: []))

        await rig.model.loadAsync()

        #expect(rig.model.clientCount(for: vip) == 2)
        #expect(rig.model.clientCount(for: sensitive) == 1)
        #expect(rig.model.errorMessage == nil && rig.model.hasLoaded && !rig.model.isLoading)
        #expect(!rig.model.showsEmptyState && !rig.model.showsSkeleton)
    }

    @Test("Before the first read the counts are unknown, not zero")
    func countsAreUnknownUntilLoaded() async throws {
        let rig = try await makeRig()
        let vip = try tag("VIP", in: rig)
        #expect(rig.model.clientCount(for: vip) == nil)
        #expect(!rig.model.hasLoaded && !rig.model.showsEmptyState)
    }

    @Test("With no tags the empty state shows once the read is done")
    func emptyState() async throws {
        let rig = try await makeRig(withTags: false)
        #expect(!rig.model.showsEmptyState)

        await rig.model.loadAsync()

        #expect(rig.model.tags.isEmpty && rig.model.showsEmptyState)
    }

    @Test("When the vault cannot be read the screen says so instead of showing an empty list")
    func loadFailure() async {
        let profile = ProfileService(vault: VaultService(repository: nil))
        let model = TagsViewModel(profile: profile, clients: nil)

        await model.loadAsync()

        #expect(model.errorMessage != nil)
        #expect(!model.showsEmptyState && model.hasLoaded && !model.isLoading)
    }

    @Test("A tag another screen added while this one was closed shows up when it is opened")
    func loadPicksUpNewTags() async throws {
        let rig = try await makeRig()
        try await rig.repository.save(Fixtures.tag("Added inline", position: 5))

        await rig.model.loadAsync()

        #expect(rig.model.tags.map(\.name) == ["VIP", "Sensitive Skin", "Added inline"])
        #expect(rig.model.clientCount(for: rig.model.tags[2]) == 0)
    }

    @Test("Loading again after an error clears it")
    func retryClearsTheError() async throws {
        let rig = try await makeRig()
        let broken = TagsViewModel(profile: ProfileService(vault: VaultService(repository: nil)), clients: nil)
        await broken.loadAsync()
        #expect(broken.errorMessage != nil)

        await rig.model.loadAsync()
        #expect(rig.model.errorMessage == nil)
    }

    // MARK: - Adding and editing

    @Test("A new tag is added at the end with its color, and starts with zero clients")
    func addsATag() async throws {
        let rig = try await makeRig()
        await rig.model.loadAsync()

        let saved = await rig.model.save(name: "  Bridal ", color: .sage, editing: nil)

        #expect(saved)
        let added = try tag("Bridal", in: rig)
        #expect(added.colorToken == "sage" && added.position == 2)
        #expect(rig.model.clientCount(for: added) == 0)
        #expect(rig.profile.tags.map(\.name) == ["VIP", "Sensitive Skin", "Bridal"])
        #expect(try await rig.repository.tags().map(\.name) == ["VIP", "Sensitive Skin", "Bridal"])
        #expect(rig.model.saveErrorMessage == nil)
    }

    @Test("A name that is empty, too long or already taken saves nothing and says nothing went wrong")
    func refusesBadNames() async throws {
        let rig = try await makeRig()
        await rig.model.loadAsync()

        let empty = await rig.model.save(name: "  ", color: .rose, editing: nil)
        let long = await rig.model.save(name: String(repeating: "x", count: 31), color: .rose, editing: nil)
        let taken = await rig.model.save(name: "sensitive SKIN", color: .rose, editing: nil)

        #expect(!empty && !long && !taken)
        #expect(try await rig.repository.tags().count == 2)
        #expect(rig.model.saveErrorMessage == nil)
        #expect(rig.model.checkName("vip") == .duplicate)
        #expect(rig.model.checkName("Fine") == .accepted("Fine"))
    }

    @Test("Renaming and recoloring a tag keeps its place and the number of clients that carry it")
    func editsATag() async throws {
        let rig = try await makeRig()
        let vip = try tag("VIP", in: rig)
        try await rig.repository.save(Fixtures.client("Ana", tags: [vip]))
        await rig.model.loadAsync()

        let saved = await rig.model.save(name: "vip", color: .peach, editing: vip)

        #expect(saved)
        let edited = try tag("vip", in: rig)
        #expect(edited.id == vip.id && edited.position == vip.position && edited.colorToken == "peach")
        #expect(rig.model.clientCount(for: edited) == 1)
        #expect(rig.model.tags.count == 2)
    }

    // MARK: - Deleting

    @Test("Deleting a tag removes it from the list and from the clients, and the clients stay")
    func deletesATag() async throws {
        let rig = try await makeRig()
        let vip = try tag("VIP", in: rig)
        let ana = Fixtures.client("Ana", tags: [vip])
        try await rig.repository.save(ana)
        try await rig.repository.save(Fixtures.client("Bia", tags: [vip]))
        await rig.model.loadAsync()
        #expect(rig.model.clientCount(for: vip) == 2)

        let deleted = await rig.model.delete(vip)

        #expect(deleted)
        #expect(rig.model.tags.map(\.name) == ["Sensitive Skin"])
        #expect(rig.model.clientCount(for: vip) == nil)
        #expect(try await rig.repository.client(id: ana.id)?.tagIDs == [])
        #expect(try await rig.repository.allClients().count == 2)
        #expect(rig.profile.tags.map(\.name) == ["Sensitive Skin"])
    }

    // MARK: - Reordering

    @Test("A drag reorders the list at once and writes only the tags that changed")
    func reorders() async throws {
        let repository = FakeBusinessRepository()
        await repository.seed(Fixtures.result(tagKeys: ["est.vip", "est.sensitive"]))
        let profile = ProfileService(repository: repository)
        await profile.load()
        let model = TagsViewModel(profile: profile, clients: InMemoryClientRecordRepository())
        try await repository.save([Fixtures.tag("Bridal", position: 2)])
        await model.loadAsync()
        let writesBefore = await repository.writeCount

        await model.moveAsync(from: [2], to: 0)

        #expect(model.tags.map(\.name) == ["Bridal", "VIP", "Sensitive Skin"])
        #expect(model.tags.map(\.position) == [0, 1, 2])
        #expect(profile.tags.map(\.name) == ["Bridal", "VIP", "Sensitive Skin"])
        #expect(await repository.storedTags().map(\.name) == ["Bridal", "VIP", "Sensitive Skin"])
        // One write for the whole drag, however many tags it renumbered.
        #expect(await repository.writeCount == writesBefore + 1)
    }

    @Test("Dropping a tag where it already was writes nothing")
    func dropInPlace() async throws {
        let repository = FakeBusinessRepository()
        await repository.seed(Fixtures.result())
        let profile = ProfileService(repository: repository)
        await profile.load()
        let model = TagsViewModel(profile: profile, clients: InMemoryClientRecordRepository())
        await model.loadAsync()
        let writesBefore = await repository.writeCount

        await model.moveAsync(from: [0], to: 1)
        await model.moveAsync(from: [1], to: 2)

        #expect(model.tags.map(\.name) == ["VIP", "Sensitive Skin"])
        #expect(await repository.writeCount == writesBefore)
    }

    @Test("The button's fire-and-forget entry point reorders the same way")
    func fireAndForgetMove() async throws {
        let rig = try await makeRig()
        await rig.model.loadAsync()

        rig.model.move(from: [0], to: 2)

        await Wait.untilMain { rig.model.tags.map(\.name) == ["Sensitive Skin", "VIP"] }
        #expect(await Wait.until { await storedNames(rig) == ["Sensitive Skin", "VIP"] })
    }

    // MARK: - When saving fails

    @Test("A refused write leaves the list as it was and says what happened")
    func failedWrites() async throws {
        let repository = FakeBusinessRepository()
        await repository.seed(Fixtures.result())
        let profile = ProfileService(repository: repository)
        await profile.load()
        let model = TagsViewModel(profile: profile, clients: InMemoryClientRecordRepository())
        await model.loadAsync()
        let before = model.tags
        await repository.setFailsWrites(true)

        let added = await model.save(name: "Bridal", color: .sage, editing: nil)
        #expect(!added && model.tags == before && model.saveErrorMessage != nil)

        model.dismissSaveError()
        #expect(model.saveErrorMessage == nil)

        let renamed = await model.save(name: "Renamed", color: .sage, editing: before[0])
        #expect(!renamed && model.tags == before && model.saveErrorMessage != nil)

        let deleted = await model.delete(before[0])
        #expect(!deleted && model.tags == before && profile.tags == before)

        await model.moveAsync(from: [0], to: 2)
        #expect(model.tags == before, "a drag that could not be saved goes back")
        #expect(model.saveErrorMessage != nil)
    }

    @Test("The next successful change clears the error of the last failed one")
    func recoveryClearsTheError() async throws {
        let repository = FakeBusinessRepository()
        await repository.seed(Fixtures.result())
        let profile = ProfileService(repository: repository)
        await profile.load()
        let model = TagsViewModel(profile: profile, clients: InMemoryClientRecordRepository())
        await model.loadAsync()
        await repository.setFailsWrites(true)
        _ = await model.save(name: "Bridal", color: .sage, editing: nil)
        #expect(model.saveErrorMessage != nil)

        await repository.setFailsWrites(false)
        let saved = await model.save(name: "Bridal", color: .sage, editing: nil)

        #expect(saved && model.saveErrorMessage == nil)
    }

    // MARK: - Suggestions

    @Test("A new tag starts with the color the fewest tags use")
    func suggestsAColor() async throws {
        let rig = try await makeRig()
        #expect(rig.model.suggestedColor == TagRules.suggestedColor(among: rig.model.tags))
        // VIP is rose, Sensitive Skin is sage in the test catalog: peach is the first color nobody has.
        #expect(rig.model.suggestedColor == .peach)
    }
}
