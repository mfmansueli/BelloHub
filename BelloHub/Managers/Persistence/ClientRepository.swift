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

    /// Combines two profiles of the same person: appointments, treatment records (with their corrections), photos,
    /// incidents, consents, health forms and session plans of `mergedID` move to `keptID`, the two client values are
    /// combined by `ClientMerger`, and the merged profile is deleted. All or nothing. Moving a record is not an edit
    /// of it, so a locked record moves with its lock and its corrections intact.
    ///
    /// **The registration ledger is not touched** (D42): the merged profile's entry stays, so a merge never frees a
    /// free registration, and it never adds one. Throws `notFound` when either client does not exist, and when the
    /// two ids are the same (there is no second profile). Returns the kept client as stored.
    @discardableResult
    func mergeClient(keeping keptID: UUID, merging mergedID: UUID) async throws -> Client

    /// Every client id ever registered, with the day. Includes deleted clients.
    func registrationLedger() async throws -> [RegistrationLedgerEntry]

    func healthForms(for clientID: UUID) async throws -> [HealthForm]
    func save(_ form: HealthForm) async throws
    /// Stores a form that arrived from the sealed mailbox, **once per mailbox item**: importing the same
    /// `importedFromItemID` again changes nothing and returns false (a crash between import and acknowledge is safe).
    func importHealthForm(_ form: HealthForm) async throws -> Bool

    /// Her consent records for one client (D55), the most recent first.
    func consents(for clientID: UUID) async throws -> [ConsentRecord]
    func save(_ consent: ConsentRecord) async throws
    /// Removes one consent record and its document. Deleting an id that is not there changes nothing.
    func deleteConsent(id: UUID) async throws

    func sessionPlans(for clientID: UUID) async throws -> [SessionPlan]
    func save(_ plan: SessionPlan) async throws
}
