//
//  VaultIndex.swift
//  BelloHub
//

import Foundation

/// The non-sensitive columns a record exposes for queries and sorting: who owns it, when, and in what state. These
/// stay in the clear in the store (names, dates, statuses); everything clinical is sealed (D26).
struct VaultIndex: Equatable, Sendable {
    var ownerID: UUID?
    var secondaryID: UUID?
    var dateA: Date?
    var dateB: Date?
    var textKey: String?
    var statusRaw: String?

    init(ownerID: UUID? = nil, secondaryID: UUID? = nil, dateA: Date? = nil, dateB: Date? = nil,
         textKey: String? = nil, statusRaw: String? = nil) {
        self.ownerID = ownerID
        self.secondaryID = secondaryID
        self.dateA = dateA
        self.dateB = dateB
        self.textKey = textKey
        self.statusRaw = statusRaw
    }
}
