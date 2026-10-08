//
//  SwiftDataClientRecordRepository+Merge.swift
//  BelloHub
//

import Foundation
import SwiftData

extension SwiftDataClientRecordRepository {
    @discardableResult
    func mergeClient(keeping keptID: UUID, merging mergedID: UUID) throws -> Client {
        guard keptID != mergedID, let keptItem = try item(kind: .client, id: keptID),
              let mergedItem = try item(kind: .client, id: mergedID) else {
            throw VaultRepositoryError.notFound
        }
        // Everything is read first, and read strictly: an unreadable record must stop the merge, never be left behind
        // on a profile that is about to disappear. Nothing has been changed until all of it decoded.
        var combined = ClientMerger.merged(
            keeping: try value(Client.self, from: keptItem), merging: try value(Client.self, from: mergedItem)
        )
        combined.updatedAt = clock()
        let appointments = try strictValues(Appointment.self, owner: mergedID)
        let records = try strictValues(TreatmentRecord.self, owner: mergedID)
        let incidents = try strictValues(Incident.self, owner: mergedID)
        let photos = try strictValues(Photo.self, owner: mergedID)
        let forms = try strictValues(HealthForm.self, owner: mergedID)
        let consents = try strictValues(Consent.self, owner: mergedID)
        let plans = try strictValues(SessionPlan.self, owner: mergedID)

        do {
            try upsert(combined)
            // A record or incident moves with its lock and its corrections: only the owner changes, so this goes
            // around `save(_:)`, which refuses to edit a locked one. Photo bytes are keyed by the photo's id and stay.
            try reassign(appointments, to: keptID, owner: \.clientID)
            try reassign(records, to: keptID, owner: \.clientID)
            try reassign(incidents, to: keptID, owner: \.clientID)
            try reassign(photos, to: keptID, owner: \.clientID)
            try reassign(forms, to: keptID, owner: \.clientID)
            try reassign(consents, to: keptID, owner: \.clientID)
            try reassign(plans, to: keptID, owner: \.clientID)
            // The registration ledger is deliberately left alone (D42).
            delete([mergedItem])
            try commit()
        } catch {
            modelContext.rollback()
            throw error
        }
        return combined
    }

    /// Every item of a kind that belongs to `owner`, decoded; one that cannot be read throws instead of being skipped.
    private func strictValues<Value: VaultStorable>(_ type: Value.Type, owner: UUID) throws -> [Value] {
        try items(kind: Value.kind, ownerID: owner).map { try value(type, from: $0) }
    }

    private func reassign<Value: VaultStorable>(
        _ values: [Value], to keptID: UUID, owner: WritableKeyPath<Value, UUID>
    ) throws {
        for var moved in values {
            moved[keyPath: owner] = keptID
            try upsert(moved)
        }
    }
}
