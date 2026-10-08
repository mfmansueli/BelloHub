//
//  FakeClientRegistrar.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A registration gate a ViewModel test scripts: the outcome it returns, and every client it was asked to register.
@MainActor
final class FakeClientRegistrar: ClientRegistering {
    var usage = RegistrationUsage.unknown
    var outcome = RegistrationOutcome.registered
    var importResult = ClientImportResult()
    private(set) var registered: [Client] = []
    private(set) var imported: [[Client]] = []
    private(set) var refreshCount = 0

    func refreshUsage() async {
        refreshCount += 1
    }

    func register(_ client: Client) async throws -> RegistrationOutcome {
        registered.append(client)
        return outcome
    }

    func importClients(_ clients: [Client]) async throws -> ClientImportResult {
        imported.append(clients)
        return importResult
    }
}
