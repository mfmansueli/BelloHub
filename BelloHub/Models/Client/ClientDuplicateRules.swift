//
//  ClientDuplicateRules.swift
//  BelloHub
//

import Foundation

/// When two client records are the same person for the registration gate: the same id, or the same phone number in
/// international form. One owner for the rule (CLAUDE.md section 2): the gate, the importers and the new-client form
/// all ask here. Names are not compared (two Anas are two clients).
enum ClientDuplicateRules {
    /// The existing client `candidate` duplicates, if any. A client never duplicates itself (same id).
    static func existing(matching candidate: Client, in clients: [Client]) -> Client? {
        if let sameID = clients.first(where: { $0.id == candidate.id }) { return sameID }
        guard let phone = normalized(candidate.phoneE164) else { return nil }
        return clients.first { normalized($0.phoneE164) == phone }
    }

    /// Splits a batch into the rows to add and the rows to skip: a row is skipped when it matches an existing client
    /// or an earlier row of the batch. Order is kept. Ids and phones are looked up in sets, so a batch of thousands of
    /// rows against thousands of clients stays linear (the rule is the same as `existing(matching:in:)`).
    static func partition(_ batch: [Client], existing: [Client]) -> (fresh: [Client], duplicates: [Client]) {
        var knownIDs = Set(existing.map(\.id))
        var knownPhones = Set(existing.compactMap { normalized($0.phoneE164) })
        var fresh: [Client] = []
        var duplicates: [Client] = []
        for client in batch {
            let phone = normalized(client.phoneE164)
            if knownIDs.contains(client.id) || (phone.map(knownPhones.contains) ?? false) {
                duplicates.append(client)
            } else {
                fresh.append(client)
                knownIDs.insert(client.id)
                if let phone { knownPhones.insert(phone) }
            }
        }
        return (fresh, duplicates)
    }

    private static func normalized(_ phone: String?) -> String? {
        guard let phone = phone?.trimmingCharacters(in: .whitespaces), !phone.isEmpty else { return nil }
        return phone
    }
}
