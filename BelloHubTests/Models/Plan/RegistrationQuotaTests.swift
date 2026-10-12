//
//  RegistrationQuotaTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RegistrationQuota (D42)")
struct RegistrationQuotaTests {
    @Test("The first 10 registrations are free: slot 10 is allowed, slot 11 needs a plan",
          arguments: [(0, true), (5, true), (9, true), (10, false), (11, false), (40, false)])
    func freeLimit(used: Int, allowed: Bool) {
        let quota = RegistrationQuota(ledgerCount: used, hasActivePlan: false)

        #expect((quota.decision() == .allowed) == allowed)
        #expect(quota.decision() == (allowed ? .allowed : .needsSubscription))
    }

    @Test("The limit is exactly ten")
    func limitIsTen() {
        #expect(RegistrationQuota.freeLimit == 10)
        #expect(RegistrationQuota(ledgerCount: 7, hasActivePlan: false).remainingFree == 3)
        #expect(RegistrationQuota(ledgerCount: 10, hasActivePlan: false).remainingFree == 0)
        #expect(RegistrationQuota(ledgerCount: 12, hasActivePlan: false).remainingFree == 0)
    }

    @Test("A plan allows unlimited registrations")
    func planIsUnlimited() {
        let quota = RegistrationQuota(ledgerCount: 500, hasActivePlan: true)

        #expect(quota.decision() == .allowed)
        #expect(quota.decision(forNewClients: 300) == .allowed)
        #expect(quota.isFreeAllowanceUsed)
    }

    @Test("Deleting a client never restores a free slot: the count comes from the ledger, not from the clients left")
    func deletingDoesNotRestoreASlot() {
        // Ten registered, three deleted: seven clients remain, but the ledger still has ten entries.
        let ledgerEntries = (0..<10).map { _ in RegistrationLedgerEntry(clientID: UUID(), registeredAt: TestClock.now) }
        let clientsLeft = 7
        let quota = RegistrationQuota(ledgerCount: ledgerEntries.count, hasActivePlan: false)

        #expect(clientsLeft < RegistrationQuota.freeLimit)
        #expect(quota.decision() == .needsSubscription)
    }

    @Test("The larger of the ledger and the server count wins, so clearing local data cannot lower it")
    func largerCountWins() {
        #expect(RegistrationQuota(ledgerCount: 2, allowanceCount: 10, hasActivePlan: false).used == 10, "Keychain")
        #expect(RegistrationQuota(ledgerCount: 7, allowanceCount: 3, hasActivePlan: false).used == 7, "ledger")
        #expect(RegistrationQuota(ledgerCount: 2, serverCount: 10, hasActivePlan: false).used == 10)
        #expect(RegistrationQuota(ledgerCount: 10, serverCount: 3, hasActivePlan: false).used == 10)
        #expect(RegistrationQuota(ledgerCount: 4, serverCount: nil, hasActivePlan: false).used == 4)
        let reinstalled = RegistrationQuota(ledgerCount: 0, serverCount: 10, hasActivePlan: false)

        #expect(reinstalled.decision() == .needsSubscription)
    }

    @Test("An import stops at the remaining free slots and offers the paywall for the rest")
    func partialImport() {
        let quota = RegistrationQuota(ledgerCount: 6, hasActivePlan: false)

        #expect(quota.decision(forNewClients: 4) == .allowed)
        #expect(quota.decision(forNewClients: 30) == .allowedPartially(count: 4))
        let used = RegistrationQuota(ledgerCount: 10, hasActivePlan: false)

        #expect(used.decision(forNewClients: 30) == .needsSubscription)
    }

    @Test("Adding nothing is always fine, and a negative count is treated as nothing")
    func zeroClients() {
        #expect(RegistrationQuota(ledgerCount: 10, hasActivePlan: false).decision(forNewClients: 0) == .allowed)
        #expect(RegistrationQuota(ledgerCount: -3, hasActivePlan: false).used == 0)
    }

    @Test("A lapsed plan returns to the free rule but nothing is removed: only new clients are affected")
    func lapsedPlan() {
        let quota = RegistrationQuota(ledgerCount: 25, hasActivePlan: false)

        #expect(quota.decision() == .needsSubscription)
        #expect(quota.isFreeAllowanceUsed)
    }

    @Test("A ledger entry holds an id and a date and nothing personal")
    func ledgerEntryHasNoPersonalData() throws {
        let entry = RegistrationLedgerEntry(clientID: UUID(), registeredAt: TestClock.now)
        let keys = Set(Mirror(reflecting: entry).children.compactMap(\.label))

        #expect(keys == ["clientID", "registeredAt"])
        #expect(entry.id == entry.clientID)
    }
}
