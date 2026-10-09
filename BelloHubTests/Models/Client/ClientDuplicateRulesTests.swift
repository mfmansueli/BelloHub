//
//  ClientDuplicateRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientDuplicateRules")
struct ClientDuplicateRulesTests {
    private func makePerson(_ name: String = "Ana Costa", phone: String? = nil, id: UUID = UUID()) -> Client {
        Client(id: id, name: name, phoneE164: phone, createdAt: TestClock.now)
    }

    // MARK: - One candidate

    @Test("The same id is the same client")
    func sameID() {
        let existing = makePerson(phone: "+5511900000001")
        var edited = existing
        edited.name = "Ana C. Costa"
        edited.phoneE164 = "+5511900000002"

        #expect(ClientDuplicateRules.existing(matching: edited, in: [existing])?.id == existing.id)
    }

    @Test("The same phone under another id is a duplicate")
    func samePhone() {
        let existing = makePerson("Ana", phone: "+5511900000001")
        let candidate = makePerson("Someone else", phone: "+5511900000001")

        #expect(ClientDuplicateRules.existing(matching: candidate, in: [existing])?.id == existing.id)
    }

    @Test("A name alone is not a duplicate: two Anas are two clients")
    func nameAloneIsNotADuplicate() {
        let existing = makePerson("Ana Costa", phone: "+5511900000001")
        let candidate = makePerson("Ana Costa", phone: "+5511900000002")

        #expect(ClientDuplicateRules.existing(matching: candidate, in: [existing]) == nil)
    }

    @Test("Two clients without a phone are never duplicates of each other")
    func noPhoneNeverMatches() {
        let existing = makePerson("Ana Costa", phone: nil)
        let candidate = makePerson("Ana Costa", phone: nil)

        #expect(ClientDuplicateRules.existing(matching: candidate, in: [existing]) == nil)
    }

    @Test("A blank phone counts as no phone")
    func blankPhoneIsNoPhone() {
        let existing = makePerson("A", phone: "   ")
        let candidate = makePerson("B", phone: "")

        #expect(ClientDuplicateRules.existing(matching: candidate, in: [existing]) == nil)
    }

    @Test("Spaces around a phone do not hide a duplicate")
    func spacesAreTrimmed() {
        let existing = makePerson(phone: "+5511900000001")
        let candidate = makePerson("Other", phone: " +5511900000001 ")

        #expect(ClientDuplicateRules.existing(matching: candidate, in: [existing]) != nil)
    }

    @Test("The id wins over the phone when both match different clients")
    func idWinsOverPhone() {
        let byID = makePerson("By id", phone: "+5511900000001")
        let byPhone = makePerson("By phone", phone: "+5511900000002")
        let candidate = makePerson("Candidate", phone: "+5511900000002", id: byID.id)

        #expect(ClientDuplicateRules.existing(matching: candidate, in: [byPhone, byID])?.id == byID.id)
    }

    // MARK: - A batch

    @Test("A batch is split into fresh rows and duplicates, and keeps its order")
    func partitionKeepsTheOrder() {
        let existing = [makePerson("Old 1", phone: "+5511900000001"), makePerson("Old 2", phone: "+5511900000002")]
        let batch = [
            makePerson("New A", phone: "+5511900000010"),
            makePerson("Dup of old 2", phone: "+5511900000002"),
            makePerson("New B", phone: "+5511900000011"),
            makePerson("Dup of old 1", phone: "+5511900000001"),
            makePerson("New C", phone: nil)
        ]

        let (fresh, duplicates) = ClientDuplicateRules.partition(batch, existing: existing)

        #expect(fresh.map(\.name) == ["New A", "New B", "New C"])
        #expect(duplicates.map(\.name) == ["Dup of old 2", "Dup of old 1"])
    }

    @Test("A row repeated inside the batch is a duplicate of the first one")
    func duplicatesWithinTheBatch() {
        let batch = [
            makePerson("First", phone: "+5511900000010"),
            makePerson("Second", phone: "+5511900000011"),
            makePerson("First again", phone: "+5511900000010"),
            makePerson("First a third time", phone: "+5511900000010")
        ]

        let (fresh, duplicates) = ClientDuplicateRules.partition(batch, existing: [])

        #expect(fresh.map(\.name) == ["First", "Second"])
        #expect(duplicates.map(\.name) == ["First again", "First a third time"])
    }

    @Test("The same id twice in a batch counts once")
    func sameIDWithinTheBatch() {
        let id = UUID()
        let batch = [makePerson("One", id: id), makePerson("Two", phone: "+5511900000010", id: id)]

        let (fresh, duplicates) = ClientDuplicateRules.partition(batch, existing: [])

        #expect(fresh.count == 1 && duplicates.count == 1)
    }

    @Test("An empty batch has nothing to split")
    func emptyBatch() {
        let (fresh, duplicates) = ClientDuplicateRules.partition([], existing: [makePerson(phone: "+5511900000001")])

        #expect(fresh.isEmpty && duplicates.isEmpty)
    }

    @Test("Names without phones all stay: nothing to compare them by")
    func namesWithoutPhones() {
        let batch = (1...5).map { makePerson("Person \($0)") }

        let (fresh, duplicates) = ClientDuplicateRules.partition(batch, existing: [])

        #expect(fresh.count == 5 && duplicates.isEmpty)
    }
}
