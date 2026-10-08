//
//  ClientRegistrationServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The registration gate (D42) against both vault implementations, which must behave the same: the first 10 clients
/// are free, a deleted client never gives a slot back, an edit and a duplicate never count, a plan lifts the limit,
/// and an import stops at the free slots that are left.
@MainActor
@Suite("ClientRegistrationService", .serialized)
struct ClientRegistrationServiceTests {
    private struct Rig {
        let service: ClientRegistrationService
        let repository: any ClientRecordRepository
        let subscription: FakeSubscriptionStatus
    }

    private func makeRig(_ flavor: RepositoryFlavor, hasPlan: Bool = false) throws -> Rig {
        let repository = try flavor.make()
        let subscription = FakeSubscriptionStatus(hasActivePlan: hasPlan)
        let service = ClientRegistrationService(
            vault: VaultService(repository: repository), subscription: subscription
        )
        return Rig(service: service, repository: repository, subscription: subscription)
    }

    /// A new client with a phone number of her own: person 7 is always `+5511900000007`.
    private func makePerson(_ index: Int, phone: String? = nil) -> Client {
        Client(
            name: "Person \(index)", phoneE164: phone ?? String(format: "+55119%08d", index),
            source: .manual, createdAt: TestClock.now
        )
    }

    private func register(_ count: Int, in rig: Rig) async throws -> [Client] {
        var clients: [Client] = []
        for index in 1...count {
            let client = makePerson(index)
            _ = try await rig.service.register(client)
            clients.append(client)
        }
        return clients
    }

    // MARK: - One client

    @Test("The first ten registrations are free", arguments: RepositoryFlavor.allCases)
    func firstTenAreFree(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)

        for index in 1...10 {
            #expect(try await rig.service.register(makePerson(index)) == .registered, "client \(index)")
        }

        #expect(rig.service.usage.used == 10)
        #expect(rig.service.usage.remainingFree == 0)
        #expect(try await rig.repository.allClients().count == 10)
    }

    @Test("The eleventh returns needsSubscription and saves nothing", arguments: RepositoryFlavor.allCases)
    func eleventhNeedsSubscription(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        _ = try await register(10, in: rig)

        let outcome = try await rig.service.register(makePerson(11))

        #expect(outcome == .needsSubscription)
        #expect(try await rig.repository.allClients().count == 10)
        #expect(try await rig.repository.registrationLedger().count == 10)
        #expect(rig.service.usage.isFreeAllowanceUsed)
    }

    @Test("Deleting a client never frees a slot", arguments: RepositoryFlavor.allCases)
    func deleteNeverFreesASlot(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        let clients = try await register(10, in: rig)

        try await rig.repository.deleteClient(id: clients[0].id)
        await rig.service.refreshUsage()

        #expect(rig.service.usage.used == 10, "the ledger still counts the deleted client")
        #expect(try await rig.service.register(makePerson(11)) == .needsSubscription)
        #expect(try await rig.repository.allClients().count == 9)
    }

    @Test("An edit returns updated and does not count", arguments: RepositoryFlavor.allCases)
    func editDoesNotCount(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        let client = makePerson(1)
        _ = try await rig.service.register(client)

        var edited = client
        edited.name = "Person One, edited"
        let outcome = try await rig.service.register(edited)

        #expect(outcome == .updated)
        #expect(rig.service.usage.used == 1)
        #expect(try await rig.repository.client(id: client.id)?.name == "Person One, edited")
    }

    @Test("An existing client stays editable after the free registrations are used",
          arguments: RepositoryFlavor.allCases)
    func editAtTheLimit(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        let clients = try await register(10, in: rig)

        var edited = clients[4]
        edited.name = "Renamed"
        #expect(try await rig.service.register(edited) == .updated)
        #expect(try await rig.repository.client(id: edited.id)?.name == "Renamed")
    }

    @Test("The same id twice never counts twice", arguments: RepositoryFlavor.allCases)
    func sameIDTwice(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        let client = makePerson(1)

        #expect(try await rig.service.register(client) == .registered)
        #expect(try await rig.service.register(client) == .updated)

        #expect(try await rig.repository.registrationLedger().count == 1)
        #expect(try await rig.repository.allClients().count == 1)
    }

    @Test("The same phone under another id is a duplicate: nothing is saved and nothing counts",
          arguments: RepositoryFlavor.allCases)
    func samePhoneIsADuplicate(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        let first = makePerson(1)
        _ = try await rig.service.register(first)

        let other = Client(name: "Someone else", phoneE164: first.phoneE164, createdAt: TestClock.now)
        let outcome = try await rig.service.register(other)

        #expect(outcome == .duplicate(existingID: first.id))
        #expect(try await rig.repository.allClients().count == 1)
        #expect(try await rig.repository.registrationLedger().count == 1)
        #expect(rig.service.usage.used == 1)
    }

    @Test("A duplicate is a duplicate even when the free registrations are used", arguments: RepositoryFlavor.allCases)
    func duplicateAtTheLimit(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        let clients = try await register(10, in: rig)

        let again = Client(name: "Again", phoneE164: clients[2].phoneE164, createdAt: TestClock.now)

        #expect(try await rig.service.register(again) == .duplicate(existingID: clients[2].id))
    }

    @Test("A name alone is not a duplicate", arguments: RepositoryFlavor.allCases)
    func nameAloneIsNotADuplicate(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        let first = Client(name: "Ana Costa", phoneE164: "+5511900000001", createdAt: TestClock.now)
        let second = Client(name: "Ana Costa", phoneE164: "+5511900000002", createdAt: TestClock.now)

        #expect(try await rig.service.register(first) == .registered)
        #expect(try await rig.service.register(second) == .registered)
    }

    // MARK: - A plan

    @Test("With a plan there is no limit and the ledger keeps counting", arguments: RepositoryFlavor.allCases)
    func planLiftsTheLimit(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor, hasPlan: true)

        for index in 1...12 {
            #expect(try await rig.service.register(makePerson(index)) == .registered, "client \(index)")
        }

        #expect(rig.service.usage.isUnlimited)
        #expect(rig.service.usage.used == 12, "the ledger counts past ten")
        #expect(try await rig.repository.registrationLedger().count == 12)
    }

    @Test("When the plan ends the limit is back, and existing clients stay", arguments: RepositoryFlavor.allCases)
    func planEnds(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor, hasPlan: true)
        _ = try await register(12, in: rig)

        rig.subscription.hasActivePlan = false

        #expect(try await rig.service.register(makePerson(13)) == .needsSubscription)
        #expect(try await rig.repository.allClients().count == 12)
    }

    // MARK: - Importing

    @Test("An import stops at the free slots that are left: 4 left and 30 rows register 4 and block 26",
          arguments: RepositoryFlavor.allCases)
    func importStopsAtTheRemainingSlots(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        _ = try await register(6, in: rig)

        let batch = (101...130).map { makePerson($0) }
        let result = try await rig.service.importClients(batch)

        #expect(result == ClientImportResult(registered: 4, duplicates: 0, malformed: 0, blocked: 26))
        #expect(try await rig.repository.allClients().count == 10)
        #expect(rig.service.usage.used == 10)
    }

    @Test("The rows registered are the first ones of the batch, in order", arguments: RepositoryFlavor.allCases)
    func importKeepsTheOrder(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        _ = try await register(8, in: rig)
        let batch = (101...105).map { makePerson($0) }

        _ = try await rig.service.importClients(batch)

        let saved = Set(try await rig.repository.allClients().map(\.id))
        #expect(saved.contains(batch[0].id) && saved.contains(batch[1].id))
        #expect(!saved.contains(batch[2].id) && !saved.contains(batch[4].id))
    }

    @Test("An import skips duplicates first, then blocks what does not fit", arguments: RepositoryFlavor.allCases)
    func importSkipsDuplicatesBeforeBlocking(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        let existing = try await register(8, in: rig)
        let fresh = (101...103).map { makePerson($0) }
        let batch = [
            makePerson(201, phone: existing[0].phoneE164), // already in her list
            makePerson(202, phone: existing[1].phoneE164), // already in her list
            fresh[0], fresh[1], fresh[2],
            makePerson(203, phone: fresh[0].phoneE164) // repeated inside the batch
        ]

        let result = try await rig.service.importClients(batch)

        #expect(result.duplicates == 3)
        #expect(result.registered == 2, "two free slots were left")
        #expect(result.blocked == 1)
        #expect(try await rig.repository.allClients().count == 10)
    }

    @Test("With no free slot left an import registers nothing and blocks every row",
          arguments: RepositoryFlavor.allCases)
    func importWithNoSlotLeft(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        _ = try await register(10, in: rig)

        let result = try await rig.service.importClients((101...105).map { makePerson($0) })

        #expect(result == ClientImportResult(registered: 0, duplicates: 0, malformed: 0, blocked: 5))
        #expect(try await rig.repository.allClients().count == 10)
    }

    @Test("With a plan an import registers every row", arguments: RepositoryFlavor.allCases)
    func importWithAPlan(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor, hasPlan: true)
        _ = try await register(10, in: rig)

        let result = try await rig.service.importClients((101...130).map { makePerson($0) })

        #expect(result.registered == 30)
        #expect(result.blocked == 0)
        #expect(rig.service.usage.used == 40)
    }

    @Test("A plan imports 2,000 clients through the gate in a reasonable time (the duplicate check is not quadratic)",
          arguments: RepositoryFlavor.allCases)
    func importTwoThousand(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor, hasPlan: true)
        let batch = (1...2_000).map { makePerson($0) }
        let clock = ContinuousClock()
        let started = clock.now

        let result = try await rig.service.importClients(batch)
        let elapsed = clock.now - started

        #expect(result.registered == 2_000)
        #expect(try await rig.repository.allClients().count == 2_000)
        #expect(elapsed < .seconds(60), "took \(elapsed)")
    }

    @Test("An empty import changes nothing", arguments: RepositoryFlavor.allCases)
    func emptyImport(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)

        #expect(try await rig.service.importClients([]) == ClientImportResult())
        #expect(rig.service.usage.used == 0)
    }

    // MARK: - The counter

    @Test("The counter follows every call", arguments: RepositoryFlavor.allCases)
    func usageUpdatesAfterEachCall(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        #expect(rig.service.usage.used == 0)

        _ = try await rig.service.register(makePerson(1))
        #expect(rig.service.usage.used == 1)

        _ = try await rig.service.importClients((2...4).map { makePerson($0) })
        #expect(rig.service.usage.used == 4)
        #expect(rig.service.usage.remainingFree == 6)
    }

    @Test("refreshUsage reads the ledger, including clients saved elsewhere", arguments: RepositoryFlavor.allCases)
    func refreshReadsTheLedger(flavor: RepositoryFlavor) async throws {
        let rig = try makeRig(flavor)
        _ = try await rig.repository.save(makePerson(1))
        _ = try await rig.repository.save(makePerson(2))

        await rig.service.refreshUsage()

        #expect(rig.service.usage.used == 2)
    }

    // MARK: - No vault

    @Test("An unavailable vault throws instead of pretending to save")
    func unavailableVaultThrows() async {
        let service = ClientRegistrationService(vault: VaultService(repository: nil))
        let person = makePerson(1)

        await #expect(throws: VaultRepositoryError.self) { try await service.register(person) }
        await #expect(throws: VaultRepositoryError.self) { try await service.importClients([person]) }
        await service.refreshUsage()
        #expect(service.usage == .unknown)
    }
}
