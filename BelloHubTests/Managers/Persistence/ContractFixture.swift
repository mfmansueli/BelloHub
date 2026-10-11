//
//  ContractFixture.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Shared by the contract suites: a clock the test moves, and a repository with one client.
struct ContractFixture {
    let clock = MutableClock()

    func seeded(_ flavor: RepositoryFlavor) throws -> (any ClientRecordRepository, Client) {
        let repository = try flavor.make(clock: clock)
        let client = Client(
            name: "Ana Costa", phoneE164: "+5511987654321", createdAt: clock.now,
            importantNote: "Sentinel-NOTE", allergies: ["fragrance"], sensitivities: ["cheeks"]
        )
        return (repository, client)
    }
}
