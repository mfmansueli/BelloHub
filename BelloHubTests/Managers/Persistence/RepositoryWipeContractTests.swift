//
//  RepositoryWipeContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// `wipeEverything` (7.1, delete account): every kind goes, the ledger included, on both vault implementations.
@Suite("Repository contract: wipe")
struct RepositoryWipeContractTests {
    private let fixture = ContractFixture()

    @Test(
        "Wiping empties clients, appointments, records, the profile, the tags and the ledger",
        arguments: RepositoryFlavor.allCases
    )
    func wipeEverything(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try fixture.seeded(flavor)
        _ = try await repository.save(client)
        try await repository.save(makeAppointment(clientID: client.id, daysFromNow: -3))
        try await repository.save(TreatmentRecord(
            clientID: client.id, serviceName: "Glow Facial", createdAt: fixture.clock.now, notes: "Sentinel-RECORD"
        ))
        try await repository.save(ProfessionalProfile(
            displayName: "Maria Silva", regionCode: "BR", timeZoneID: "America/Sao_Paulo", currencyCode: "BRL",
            appLocaleID: "pt-BR", createdAt: fixture.clock.now
        ))
        try await repository.save(Tag(id: UUID(), name: "VIP", colorToken: "rose", position: 0))
        #expect(try await repository.registrationLedger().count == 1)

        try await repository.wipeEverything()

        #expect(try await repository.allClients().isEmpty)
        #expect(try await repository.loadAppointments(in: DateInterval(start: .distantPast, end: .distantFuture))
            .isEmpty)
        #expect(try await repository.records(for: client.id).isEmpty)
        #expect(try await repository.profile() == nil)
        #expect(try await repository.tags().isEmpty)
        #expect(try await repository.registrationLedger().isEmpty)
    }

    @Test("After a wipe a new client registers as the first one again", arguments: RepositoryFlavor.allCases)
    func freshStart(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try fixture.seeded(flavor)
        _ = try await repository.save(client)
        try await repository.wipeEverything()

        _ = try await repository.save(makeClient(name: "Bia"))

        #expect(try await repository.allClients().map(\.name) == ["Bia"])
        #expect(try await repository.registrationLedger().count == 1)
    }
}
