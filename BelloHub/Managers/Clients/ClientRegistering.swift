//
//  ClientRegistering.swift
//  BelloHub
//

/// The registration gate (D42): the **only** way to create a client, whether she types one, imports many or approves a
/// booking. Edits go through it too and never count. ViewModels depend on this protocol so tests inject a fake.
@MainActor
protocol ClientRegistering: AnyObject {
    /// The free-registration counter, kept up to date after every call.
    var usage: RegistrationUsage { get }

    /// Re-reads the ledger (and, from S8, the server count).
    func refreshUsage() async

    /// Saves one client. A new client is counted; an edit, or a client whose phone another client already has, is not.
    func register(_ client: Client) async throws -> RegistrationOutcome

    /// Saves a batch, skipping duplicates and stopping at the free registrations that are left (the rest is `blocked`).
    func importClients(_ clients: [Client]) async throws -> ClientImportResult
}
