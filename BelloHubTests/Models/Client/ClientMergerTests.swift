//
//  ClientMergerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientMerger")
struct ClientMergerTests {
    private func merged(_ kept: Client, _ other: Client) -> Client {
        ClientMerger.merged(keeping: kept, merging: other)
    }

    @Test("The kept profile keeps its id, name and values; the other one fills the gaps")
    func keptWinsAndGapsAreFilled() {
        var kept = makeListedClient(name: "Ana Costa")
        kept.email = "ana@kept.com"
        var other = makeListedClient(name: "Ana C.", phone: "+5511981234410", email: "ana@other.com")
        other.birthday = Birthday(month: 3, day: 14, year: 1990)

        let result = merged(kept, other)

        #expect(result.id == kept.id && result.name == "Ana Costa")
        #expect(result.email == "ana@kept.com")
        #expect(result.phoneE164 == "+5511981234410")
        #expect(result.birthday == Birthday(month: 3, day: 14, year: 1990))
    }

    @Test("Tags and the four lists join without repeating an entry, the kept profile's first")
    func listsJoinWithoutDuplicates() {
        let shared = UUID()
        var kept = makeListedClient(name: "A", tagIDs: [shared, UUID()])
        kept.sensitivities = ["Cheeks", "Eyes"]
        kept.preferences = ["Quiet room"]
        kept.allergies = ["Fragrance"]
        var other = makeListedClient(name: "B", tagIDs: [shared, UUID()])
        other.sensitivities = ["cheeks ", "Neck"]
        other.preferences = ["Quiet Room"]
        other.recurringRequests = ["Gentle pressure"]
        other.allergies = ["Latex", "fragrance"]

        let result = merged(kept, other)

        #expect(result.tagIDs.count == 3 && result.tagIDs.first == kept.tagIDs.first)
        #expect(result.sensitivities == ["Cheeks", "Eyes", "Neck"])
        #expect(result.preferences == ["Quiet room"])
        #expect(result.recurringRequests == ["Gentle pressure"])
        #expect(result.allergies == ["Fragrance", "Latex"])
    }

    @Test("Notes: a blank one disappears, the same one is not repeated, different ones become two paragraphs")
    func notes() {
        #expect(ClientMerger.note(nil, nil) == nil)
        #expect(ClientMerger.note("  ", "Prefers mornings") == "Prefers mornings")
        #expect(ClientMerger.note("Prefers mornings", nil) == "Prefers mornings")
        #expect(ClientMerger.note("Prefers mornings", "prefers MORNINGS") == "Prefers mornings")
        let longer = "Prefers mornings and quiet rooms"
        #expect(ClientMerger.note("Prefers mornings", longer) == longer)
        #expect(ClientMerger.note("Prefers mornings", "Allergic to latex") == "Prefers mornings\n\nAllergic to latex")
    }

    @Test("What protects the client wins: booking stays stopped and reminders stay off if either profile had them so")
    func protectionWins() {
        var kept = makeListedClient(name: "A")
        var other = makeListedClient(name: "B")
        other.onlineBookingStopped = true
        other.stopReason = "Asked to pause"
        other.remindersEnabled = false

        let result = merged(kept, other)
        #expect(result.onlineBookingStopped && result.stopReason == "Asked to pause")
        #expect(!result.remindersEnabled)

        kept.onlineBookingStopped = true
        kept.stopReason = "Moved away"
        #expect(merged(kept, other).stopReason == "Moved away\n\nAsked to pause")
        #expect(merged(makeListedClient(name: "A"), makeListedClient(name: "B")).stopReason == nil)
    }

    @Test("Merging an active profile into an archived one brings her back; two archived stay archived")
    func archiveState() {
        let archived = makeListedClient(name: "A", isArchived: true)
        let active = makeListedClient(name: "B")

        #expect(!merged(archived, active).isArchived)
        #expect(merged(archived, makeListedClient(name: "C", isArchived: true)).isArchived)
        #expect(!merged(active, archived).isArchived)
    }

    @Test("She is a client since the earlier of the two profiles")
    func createdAt() {
        var kept = makeListedClient(name: "A")
        kept.createdAt = TestClock.days(-10)
        var other = makeListedClient(name: "B")
        other.createdAt = TestClock.days(-90)

        #expect(merged(kept, other).createdAt == TestClock.days(-90))
    }

    @Test("Entries are compared without regard to case, accents or width")
    func comparison() {
        #expect(ClientMerger.union(["Pressão leve"], ["pressao LEVE", "Outra"]) == ["Pressão leve", "Outra"])
        #expect(ClientMerger.union(["  ", ""], ["a"]) == ["a"])
    }
}
