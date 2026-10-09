//
//  RepositoryClientContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Repository contract: clients, ledger, observation", .serialized)
struct RepositoryClientContractTests {
    private let fixture = ContractFixture()
    private var clock: MutableClock { fixture.clock }

    private func seeded(_ flavor: RepositoryFlavor) throws -> (any ClientRecordRepository, Client) {
        try fixture.seeded(flavor)
    }

    // MARK: - Clients and the registration ledger (D42)

    @Test("A client round-trips with every field, including the sealed ones", arguments: RepositoryFlavor.allCases)
    func clientRoundTrip(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        try await repository.save(client)

        let stored = try #require(try await repository.client(id: client.id))
        #expect(stored.name == "Ana Costa")
        #expect(stored.phoneE164 == "+5511987654321")
        #expect(stored.importantNote == "Sentinel-NOTE")
        #expect(stored.allergies == ["fragrance"])
        #expect(stored.sensitivities == ["cheeks"])
        #expect(stored.createdAt == client.createdAt)
    }

    @Test("The first save of an id registers a client, an edit does not (D42)", arguments: RepositoryFlavor.allCases)
    func firstSaveRegisters(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)

        #expect(try await repository.save(client) == true)
        var edited = client
        edited.name = "Ana C. Costa"
        #expect(try await repository.save(edited) == false)
        #expect(try await repository.registrationLedger().count == 1)
        #expect(try await repository.allClients().count == 1)
    }

    @Test("Deleting a client keeps the ledger entry, so the slot never comes back (D42)",
          arguments: RepositoryFlavor.allCases)
    func deleteKeepsLedger(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: clock)
        let clients = (0..<10).map { Client(name: "Client \($0)", createdAt: clock.now) }
        for client in clients { try await repository.save(client) }
        for client in clients.prefix(4) { try await repository.deleteClient(id: client.id) }

        let ledger = try await repository.registrationLedger()
        let quota = RegistrationQuota(ledgerCount: ledger.count, hasActivePlan: false)

        #expect(try await repository.allClients().count == 6)
        #expect(ledger.count == 10)
        #expect(Set(ledger.map(\.clientID)) == Set(clients.map(\.id)))
        #expect(quota.decision() == .needsSubscription, "ten registered, four deleted: the eleventh needs a plan")
    }

    @Test("Saving the same id again after a delete does not add a ledger entry", arguments: RepositoryFlavor.allCases)
    func resaveAfterDelete(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        try await repository.save(client)
        try await repository.deleteClient(id: client.id)

        #expect(try await repository.save(client) == false)
        #expect(try await repository.registrationLedger().count == 1)
    }

    @Test("A ledger entry holds a client id and a date, never a name or a phone", arguments: RepositoryFlavor.allCases)
    func ledgerHasNoPersonalData(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        try await repository.save(client)
        let entry = try #require(try await repository.registrationLedger().first)

        #expect(entry.clientID == client.id)
        #expect(entry.registeredAt == clock.now)
    }

    @Test("Clients come back sorted the way people read names (María before Zoe, accents ignored)",
          arguments: RepositoryFlavor.allCases)
    func clientsAreSortedByName(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: clock)
        for name in ["Zoe", "María", "Ana", "Beatriz"] {
            try await repository.save(Client(name: name, createdAt: clock.now))
        }

        #expect(try await repository.allClients().map(\.name) == ["Ana", "Beatriz", "María", "Zoe"])
    }

    @Test("Deleting a client removes everything that belongs to her and nothing of anyone else",
          arguments: RepositoryFlavor.allCases)
    func deleteCascades(flavor: RepositoryFlavor) async throws {
        let (repository, ana) = try seeded(flavor)
        let bia = Client(name: "Bia", createdAt: clock.now)
        try await repository.save(ana)
        try await repository.save(bia)
        for owner in [ana, bia] {
            try await populate(repository, for: owner)
        }
        let anaRecord = try #require(try await repository.records(for: ana.id).first)

        try await repository.deleteClient(id: ana.id)

        #expect(try await repository.client(id: ana.id) == nil)
        #expect(try await repository.appointments(for: ana.id).isEmpty)
        #expect(try await repository.records(for: ana.id).isEmpty)
        #expect(try await repository.corrections(for: anaRecord.id).isEmpty)
        #expect(try await repository.incidents(for: ana.id).isEmpty)
        #expect(try await repository.photos(for: ana.id).isEmpty)
        #expect(try await repository.healthForms(for: ana.id).isEmpty)
        #expect(try await repository.consents(for: ana.id).isEmpty)
        #expect(try await repository.sessionPlans(for: ana.id).isEmpty)

        #expect(try await repository.client(id: bia.id) != nil)
        #expect(try await repository.appointments(for: bia.id).count == 1)
        #expect(try await repository.records(for: bia.id).count == 1)
        #expect(try await repository.photos(for: bia.id).count == 1)
        #expect(try await repository.healthForms(for: bia.id).count == 1)
    }

    private func populate(_ repository: any ClientRecordRepository, for client: Client) async throws {
        let start = TestClock.date("2026-09-30 15:00")
        try await repository.save(Appointment(clientID: client.id, serviceName: "Glow", startsAt: start,
                                              endsAt: start.addingTimeInterval(3_600), createdAt: start))
        let record = TreatmentRecord(clientID: client.id, serviceName: "Glow", createdAt: start, notes: "n")
        try await repository.save(record)
        clock.set(record.lockedAt.addingTimeInterval(60))
        let correction = RecordCorrection(id: UUID(), recordID: record.id, createdAt: clock.now, fieldKey: "notes",
                                          oldValue: "n", newValue: "m", reason: "r")
        try await repository.addCorrection(correction)
        clock.set(TestClock.now)
        try await repository.save(Incident(id: UUID(), clientID: client.id, recordID: record.id, occurredAt: start,
                                           severity: .mild, lockedAt: start.addingTimeInterval(86_400),
                                           needsFollowUp: false, symptoms: "s", area: nil, actionTaken: nil,
                                           followUp: nil))
        try await repository.save(Photo(id: UUID(), clientID: client.id, recordID: record.id, takenAt: start,
                                        kind: .before, visibility: .professionalOnly),
                                  data: PhotoData(image: Data([1, 2, 3]), thumbnail: Data([9])))
        try await repository.save(HealthForm(id: UUID(), clientID: client.id, formVersion: 1, filledBy: .client,
                                             isForMinor: false, signedAt: start, importedFromItemID: nil,
                                             answers: ["allergies": .no], minorName: nil))
        try await repository.save(ConsentRecord(id: UUID(), clientID: client.id, kind: .treatment, isSigned: true,
                                                signedAt: start, createdAt: start, label: "A"))
        try await repository.save(SessionPlan(id: UUID(), clientID: client.id, name: "Plan", totalSessions: 6,
                                              intervalWeeks: 4, startDate: start, remindToRebook: true))
    }

    // MARK: - Observation

    @Test("The client stream emits the list now and again after each save", arguments: RepositoryFlavor.allCases)
    func clientStream(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        let seen = Seen()
        let task = Task {
            for await list in repository.clients() { await seen.add(list.map(\.name)) }
        }
        defer { task.cancel() }

        #expect(await Wait.until { await seen.lastIs([]) })
        try await repository.save(client)
        #expect(await Wait.until { await seen.lastIs(["Ana Costa"]) })
        try await repository.deleteClient(id: client.id)
        #expect(await Wait.until { await seen.lastIs([], after: 3) })
    }

    private actor Seen {
        private var lists: [[String]] = []

        func add(_ list: [String]) {
            lists.append(list)
        }

        /// The latest list equals `expected`, and at least `after` lists have been seen.
        func lastIs(_ expected: [String], after minimum: Int = 1) -> Bool {
            lists.count >= minimum && lists.last == expected
        }
    }
}
