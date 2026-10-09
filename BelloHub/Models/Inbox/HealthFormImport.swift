//
//  HealthFormImport.swift
//  BelloHub
//

import Foundation

/// A health form that arrived through the sealed mailbox and was written into a client's record. Ids and a time only
/// (it is kept outside the vault until she opens it from the inbox); the answers are in the vault.
struct HealthFormImport: Identifiable, Hashable, Codable, Sendable {
    /// The mailbox item id.
    let id: String
    let clientID: UUID
    let formID: UUID
    let at: Date
}
