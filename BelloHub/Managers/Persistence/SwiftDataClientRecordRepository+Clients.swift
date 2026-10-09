//
//  SwiftDataClientRecordRepository+Clients.swift
//  BelloHub
//

import Foundation

extension SwiftDataClientRecordRepository {
    nonisolated func clients() -> AsyncStream<[Client]> {
        changes.stream { [self] in (try? await allClients()) ?? [] }
    }

    func allClients() throws -> [Client] {
        try values(Client.self, from: items(kind: .client))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func client(id: UUID) throws -> Client? {
        try item(kind: .client, id: id).map { try value(Client.self, from: $0) }
    }

    @discardableResult
    func save(_ client: Client) throws -> Bool {
        var stored = client
        stored.updatedAt = clock()
        try upsert(stored)
        // The ledger counts each client id once, the first time it is saved. An edit, or a re-save after a delete
        // (the same id), never adds an entry (D42).
        let isNewRegistration = try item(kind: .registration, id: client.id) == nil
        if isNewRegistration {
            try upsert(RegistrationLedgerEntry(clientID: client.id, registeredAt: clock()))
        }
        try commit()
        return isNewRegistration
    }

    func deleteClient(id: UUID) throws {
        let records = try items(kind: .treatmentRecord, ownerID: id)
        for record in records {
            try deleteItems(kind: .correction, ownerID: record.id)
        }
        let owned: [VaultKind] = [
            .appointment, .treatmentRecord, .incident, .photo, .healthForm, .consent, .patchTest, .sessionPlan
        ]
        for kind in owned {
            try deleteItems(kind: kind, ownerID: id)
        }
        if let client = try item(kind: .client, id: id) { delete([client]) }
        // The registration-ledger entry is deliberately left in place.
        try commit()
    }

    func registrationLedger() throws -> [RegistrationLedgerEntry] {
        try values(RegistrationLedgerEntry.self, from: items(kind: .registration))
            .sorted { ($0.registeredAt, $0.clientID.uuidString) < ($1.registeredAt, $1.clientID.uuidString) }
    }

    func healthForms(for clientID: UUID) throws -> [HealthForm] {
        try values(HealthForm.self, from: items(kind: .healthForm, ownerID: clientID))
            .sorted { ($0.signedAt ?? .distantPast) > ($1.signedAt ?? .distantPast) }
    }

    func save(_ form: HealthForm) throws {
        try upsert(form)
        try commit()
    }

    func importHealthForm(_ form: HealthForm) throws -> Bool {
        if let itemID = form.importedFromItemID,
           try items(kind: .healthForm).contains(where: { $0.textKey == itemID }) {
            return false
        }
        try upsert(form)
        try commit()
        return true
    }

    func consents(for clientID: UUID) throws -> [Consent] {
        try values(Consent.self, from: items(kind: .consent, ownerID: clientID))
            .sorted { $0.signedAt > $1.signedAt }
    }

    func save(_ consent: Consent) throws {
        try upsert(consent)
        try commit()
    }

    func sessionPlans(for clientID: UUID) throws -> [SessionPlan] {
        try values(SessionPlan.self, from: items(kind: .sessionPlan, ownerID: clientID))
            .sorted { $0.startDate < $1.startDate }
    }

    func save(_ plan: SessionPlan) throws {
        try upsert(plan)
        try commit()
    }
}
