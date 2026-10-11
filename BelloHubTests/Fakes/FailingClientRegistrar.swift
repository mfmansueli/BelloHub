//
//  FailingClientRegistrar.swift
//  BelloHubTests
//

@testable import BelloHub

/// A registration gate whose vault is gone: every save throws, as when the store cannot be opened or the disk is full.
@MainActor
final class FailingClientRegistrar: ClientRegistering {
    var usage = RegistrationUsage.unknown
    private(set) var importAttempts = 0

    func refreshUsage() async {}

    func register(_ client: Client) async throws -> RegistrationOutcome {
        throw VaultRepositoryError.unavailable
    }

    func knownClients() async throws -> [Client] {
        throw VaultRepositoryError.unavailable
    }

    func importClients(_ clients: [Client]) async throws -> ClientImportResult {
        importAttempts += 1
        throw VaultRepositoryError.unavailable
    }
}
