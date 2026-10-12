//
//  ClientRegistrationAllowanceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// D59: the free registrations are counted on this iPhone. The Keychain count follows every new, distinct client,
/// never goes down, is raised to the vault ledger on the first read (the migration), and the gate keeps working when
/// the Keychain does not. No server is involved.
@MainActor
@Suite("ClientRegistrationService: Keychain allowance")
struct ClientRegistrationAllowanceTests {
    private struct Rig {
        let service: ClientRegistrationService
        let repository: any ClientRecordRepository
        let allowance: FakeRegistrationAllowanceStore
        let subscription: FakeSubscriptionStatus
    }

    private func makeRig(stored: Int? = nil, hasPlan: Bool = false) -> Rig {
        let repository = InMemoryClientRecordRepository()
        let allowance = FakeRegistrationAllowanceStore(count: stored)
        let subscription = FakeSubscriptionStatus(hasActivePlan: hasPlan)
        let service = ClientRegistrationService(
            vault: VaultService(repository: repository), subscription: subscription, allowance: allowance
        )
        return Rig(service: service, repository: repository, allowance: allowance, subscription: subscription)
    }

    private func person(_ index: Int) -> Client {
        Client(name: "Person \(index)", phoneE164: String(format: "+55119%08d", index), source: .manual,
               createdAt: TestClock.now)
    }

    @Test("Each new, distinct client raises the Keychain count; an edit and a duplicate phone do not")
    func counts() async throws {
        let rig = makeRig()
        let ana = person(1)
        #expect(try await rig.service.register(ana) == .registered)
        #expect(rig.allowance.count == 1)

        var edited = ana
        edited.name = "Ana C."
        #expect(try await rig.service.register(edited) == .updated)
        var samePhone = person(2)
        samePhone.phoneE164 = ana.phoneE164
        #expect(try await rig.service.register(samePhone) == .duplicate(existingID: ana.id))
        #expect(rig.allowance.count == 1)
        #expect(rig.service.usage.used == 1)
    }

    @Test("Deleting a client never gives the slot back, and a deleted client's id coming back is not counted twice")
    func deletesNeverReturn() async throws {
        let rig = makeRig()
        let ana = person(1)
        _ = try await rig.service.register(ana)
        try await rig.repository.deleteClient(id: ana.id)
        await rig.service.refreshUsage()
        #expect(rig.service.usage.used == 1)

        #expect(try await rig.service.register(ana) == .registered)
        #expect(rig.allowance.count == 1)
    }

    @Test("The Keychain survives a wiped vault: a reinstall on this iPhone starts from the stored count")
    func keychainOutlivesTheVault() async throws {
        let rig = makeRig(stored: 10)
        await rig.service.refreshUsage()
        #expect(rig.service.usage.used == 10)
        #expect(try await rig.service.register(person(1)) == .needsSubscription)
        #expect(try await rig.repository.allClients().isEmpty)
    }

    @Test("Migration: the first read raises the Keychain to the ledger, never lowers it")
    func migration() async throws {
        let rig = makeRig(stored: 2)
        for index in 1...6 { _ = try await rig.repository.save(person(index)) }

        await rig.service.refreshUsage()
        #expect(rig.allowance.count == 6)
        #expect(rig.service.usage.used == 6)

        let ahead = makeRig(stored: 9)
        _ = try await ahead.repository.save(person(1))
        await ahead.service.refreshUsage()
        #expect(ahead.allowance.count == 9, "a higher Keychain count is kept")
        #expect(ahead.service.usage.used == 9)
    }

    @Test("Ten are free, the eleventh needs a plan, a plan makes it unlimited")
    func gate() async throws {
        let rig = makeRig()
        for index in 1...10 { #expect(try await rig.service.register(person(index)) == .registered) }
        #expect(try await rig.service.register(person(11)) == .needsSubscription)

        rig.subscription.hasActivePlan = true
        #expect(try await rig.service.register(person(11)) == .registered)
        #expect(rig.allowance.count == 11, "with a plan the count keeps going")
    }

    @Test("An import registers what fits, and the rest after she subscribes; the count follows")
    func importThenRest() async throws {
        let rig = makeRig(stored: 7)
        let rows = (1...5).map(person)

        let first = try await rig.service.importClients(rows)
        #expect(first.registered == 3 && first.blocked == 2)
        #expect(rig.allowance.count == 10)

        rig.subscription.hasActivePlan = true
        let rest = try await rig.service.importClients(rows)
        #expect(rest.registered == 2 && rest.duplicates == 3)
        #expect(rig.allowance.count == 12)
    }

    @Test("A Keychain that cannot be read or written never stops the gate: the vault ledger counts alone")
    func brokenKeychain() async throws {
        let rig = makeRig(stored: 4)
        rig.allowance.isBroken = true
        #expect(try await rig.service.register(person(1)) == .registered)
        #expect(rig.service.usage.used == 1)
        for index in 2...10 { _ = try await rig.service.register(person(index)) }
        #expect(try await rig.service.register(person(11)) == .needsSubscription)
    }

    @Test("A registration claim queued by an older version is dropped without calling the server")
    func oldQueuedClaimDropped() async {
        let rig = InboxRig(repository: FakeInboxRepository())
        defer { rig.cleanUp() }
        await rig.start()
        let before = await rig.repository.writes.count

        _ = rig.queue.enqueue(.reserveRegistrations(claims: [RegistrationClaim(person(1))]))
        await rig.queue.flushAsync()

        #expect(rig.queue.pending.isEmpty)
        #expect(await rig.repository.writes.count == before)
    }
}
