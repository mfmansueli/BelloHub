//
//  ClientRepository.swift
//  BelloHub
//

import Foundation

/// Clients and what hangs from a client: health forms, consents and session plans. The vault is the only place
/// these live (D2); sensitive fields are encrypted by the implementation (D26).
protocol ClientRepository: Sendable {
    /// The clients now, and again after every change.
    func clients() -> AsyncStream<[Client]>
    func allClients() async throws -> [Client]
    func client(id: UUID) async throws -> Client?

    /// Inserts or updates. The **first time an id is saved** a registration-ledger entry is appended (D42); an edit
    /// never is. Returns true when this call registered a new client.
    @discardableResult
    func save(_ client: Client) async throws -> Bool

    /// Deletes the client and everything that belongs to her: appointments, records, corrections, incidents, photos,
    /// health forms, consents and session plans. **The registration-ledger entry stays** (D42): it holds only an id
    /// and a date, and deleting a client never gives a free slot back.
    func deleteClient(id: UUID) async throws

    /// Every client id ever registered, with the day. Includes deleted clients.
    func registrationLedger() async throws -> [RegistrationLedgerEntry]

    func healthForms(for clientID: UUID) async throws -> [HealthForm]
    func save(_ form: HealthForm) async throws
    /// Stores a form that arrived from the sealed mailbox, **once per mailbox item**: importing the same
    /// `importedFromItemID` again changes nothing and returns false (a crash between import and acknowledge is safe).
    func importHealthForm(_ form: HealthForm) async throws -> Bool

    func consents(for clientID: UUID) async throws -> [Consent]
    func save(_ consent: Consent) async throws

    func sessionPlans(for clientID: UUID) async throws -> [SessionPlan]
    func save(_ plan: SessionPlan) async throws
}
