//
//  ImportPlanTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ImportPlan")
struct ImportPlanTests {
    private func usage(used: Int, hasPlan: Bool = false) -> RegistrationUsage {
        RegistrationUsage(quota: RegistrationQuota(ledgerCount: used, hasActivePlan: hasPlan))
    }

    /// A client created at the fixed test time, with a phone built from `number` so duplicates are easy to write.
    private func makeClient(_ name: String, phone number: Int? = nil) -> Client {
        Client(
            name: name, phoneE164: number.map { String(format: "+55119%08d", $0) }, source: .importedClients,
            createdAt: TestClock.now
        )
    }

    private func makeClients(_ count: Int, firstPhone: Int = 1) -> [Client] {
        (0..<count).map { makeClient("Person \($0)", phone: firstPhone + $0) }
    }

    private func makeEntry(_ client: Client) -> ImportEntry {
        ImportEntry(id: "row-\(client.name)", displayName: client.name, rowNumber: nil, outcome: .ready(client))
    }

    // MARK: - Counting

    @Test("A batch that fits is registered whole and says what is left", arguments: [(0, 10), (6, 4), (9, 1)])
    func fits(used: Int, chosen: Int) {
        let plan = ImportPlan(chosen: makeClients(chosen), existing: [], usage: usage(used: used))

        #expect(plan.kind == .allFree)
        #expect(plan.newClients == chosen && plan.registeredNow == chosen && plan.waiting == 0)
        #expect(plan.freeLeft == 10 - used && plan.freeLeftAfter == 10 - used - chosen)
    }

    @Test("Duplicates of her list and repeats inside the batch are not new and use no free registration")
    func duplicatesAreNotNew() {
        let existing = [makeClient("Ana", phone: 1)]
        let chosen = [makeClient("Ana again", phone: 1), makeClient("Bia", phone: 2), makeClient("Bia twin", phone: 2)]

        let plan = ImportPlan(chosen: chosen, existing: existing, usage: usage(used: 9))

        #expect(plan.chosen == 3 && plan.newClients == 1 && plan.alreadyInList == 2)
        #expect(plan.kind == .allFree && plan.registeredNow == 1 && plan.freeLeftAfter == 0)
    }

    @Test("Past the free registrations: the first new ones go through, the rest wait and are counted, never dropped")
    func exceedsTheFreeRegistrations() {
        let existing = [makeClient("Old", phone: 1)]
        // 12 chosen, one of them already in her list: 11 new, 3 free left.
        let plan = ImportPlan(chosen: makeClients(12), existing: existing, usage: usage(used: 7))

        #expect(plan.kind == .partlyFree && plan.needsPlan)
        #expect(plan.newClients == 11 && plan.alreadyInList == 1)
        #expect(plan.registeredNow == 3 && plan.waiting == 8 && plan.freeLeftAfter == 0)
        #expect(plan.registeredNow + plan.waiting + plan.alreadyInList == plan.chosen, "every row is accounted for")
    }

    @Test("Agrees with the gate: registered now is what RegistrationQuota allows for the new clients")
    func agreesWithTheQuota() {
        let quota = RegistrationQuota(ledgerCount: 7, hasActivePlan: false)
        let plan = ImportPlan(chosen: makeClients(11), existing: [], usage: RegistrationUsage(quota: quota))

        #expect(quota.decision(forNewClients: plan.newClients) == .allowedPartially(count: plan.registeredNow))
    }

    @Test("With every free registration used nobody new goes through, even past ten")
    func needsPlan() {
        for used in [10, 14] {
            let plan = ImportPlan(chosen: makeClients(3), existing: [], usage: usage(used: used))

            #expect(plan.kind == .needsPlan && plan.registeredNow == 0 && plan.waiting == 3 && plan.freeLeftAfter == 0)
        }
    }

    @Test("A plan lets every new client through and nothing waits")
    func unlimited() {
        let plan = ImportPlan(chosen: makeClients(30), existing: [], usage: usage(used: 10, hasPlan: true))

        #expect(plan.kind == .unlimited && plan.registeredNow == 30 && plan.waiting == 0 && !plan.needsPlan)
    }

    @Test("Everyone already in her list registers nobody and needs no plan")
    func nothingNew() {
        // Same phones, new ids: the same people found again.
        let plan = ImportPlan(chosen: makeClients(2), existing: makeClients(2), usage: usage(used: 10))

        #expect(plan.kind == .nothingNew && plan.waiting == 0 && !plan.needsPlan)
    }

    @Test("Nothing chosen is its own state")
    func nothingChosen() {
        #expect(ImportPlan(chosen: [], existing: [], usage: usage(used: 0)).kind == .nothingChosen)
    }

    @Test("When her list could not be read every row is counted as new, flagged as not checked")
    func unchecked() {
        let plan = ImportPlan(chosen: makeClients(4), existing: nil, usage: usage(used: 8))

        #expect(!plan.checkedDuplicates && plan.newClients == 4 && plan.registeredNow == 2 && plan.waiting == 2)
    }

    // MARK: - Small group

    @Test("A trial takes the first new rows in list order and passes over duplicates")
    func trialSelection() {
        let clients = makeClients(6)
        let existing = [makeClient("Old", phone: 2)]

        let ids = ImportPlan.trialSelection(size: 3, from: clients.map(makeEntry), existing: existing)

        #expect(ids == ["row-Person 0", "row-Person 2", "row-Person 3"])
    }

    @Test("A trial never selects more rows than exist, and size 0 selects none")
    func trialBounds() {
        let entries = makeClients(2).map(makeEntry)

        #expect(ImportPlan.trialSelection(size: 10, from: entries, existing: []).count == 2)
        #expect(ImportPlan.trialSelection(size: 0, from: entries, existing: []).isEmpty)
    }

    @Test("Trial sizes: the standard ones smaller than the list, plus what is free when that is useful")
    func trialChoices() {
        #expect(ImportPlan.trialChoices(newCount: 40, freeLeft: 10, isUnlimited: false) == [3, 5, 10])
        #expect(ImportPlan.trialChoices(newCount: 40, freeLeft: 4, isUnlimited: false) == [3, 4, 5, 10])
        #expect(ImportPlan.trialChoices(newCount: 4, freeLeft: 10, isUnlimited: false) == [3])
        #expect(ImportPlan.trialChoices(newCount: 3, freeLeft: 1, isUnlimited: false) == [1])
        #expect(ImportPlan.trialChoices(newCount: 40, freeLeft: 0, isUnlimited: true) == [3, 5, 10])
        #expect(ImportPlan.trialChoices(newCount: 2, freeLeft: 10, isUnlimited: false).isEmpty)
    }
}
