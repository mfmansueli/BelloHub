//
//  TagUsageTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("TagUsage")
struct TagUsageTests {
    /// `BelloHub.Tag`, because Swift Testing has a `Tag` of its own.
    private func makeTag(_ name: String) -> BelloHub.Tag {
        BelloHub.Tag(id: UUID(), name: name, colorToken: "rose", position: 0)
    }

    private func client(_ name: String, tags: [BelloHub.Tag], archived: Bool = false) -> Client {
        Client(name: name, tagIDs: tags.map(\.id), isArchived: archived, createdAt: TestClock.now)
    }

    @Test("Each tag is counted over the clients that carry it, and a tag nobody has is zero")
    func counts() {
        let vip = makeTag("VIP")
        let bridal = makeTag("Bridal")
        let unused = makeTag("Regular")
        let clients = [
            client("Ana", tags: [vip, bridal]), client("Bia", tags: [vip]), client("Cris", tags: [])
        ]

        let counts = TagUsage.counts(tags: [vip, bridal, unused], clients: clients)

        #expect(counts == [vip.id: 2, bridal.id: 1, unused.id: 0])
    }

    @Test("Archived clients count, because deleting the tag takes it off them too")
    func archivedCount() {
        let vip = makeTag("VIP")
        let counts = TagUsage.counts(
            tags: [vip], clients: [client("Ana", tags: [vip]), client("Bia", tags: [vip], archived: true)]
        )
        #expect(counts[vip.id] == 2)
    }

    @Test("A tag id that is not in the list is ignored, and a repeated id counts once")
    func ignoresStrangers() {
        let vip = makeTag("VIP")
        let gone = makeTag("Deleted elsewhere")
        var ana = client("Ana", tags: [vip, gone])
        ana.tagIDs.append(vip.id)

        let counts = TagUsage.counts(tags: [vip], clients: [ana])

        #expect(counts == [vip.id: 1])
    }

    @Test("No tags and no clients give no counts")
    func empty() {
        #expect(TagUsage.counts(tags: [], clients: []).isEmpty)
        let vip = makeTag("VIP")
        #expect(TagUsage.counts(tags: [vip], clients: []) == [vip.id: 0])
    }
}
