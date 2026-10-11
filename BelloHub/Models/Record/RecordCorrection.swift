//
//  RecordCorrection.swift
//  BelloHub
//

import Foundation

/// A change to a locked record: who, when, what, why. Never deleted, never edited.
struct RecordCorrection: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var recordID: UUID
    var createdAt: Date
    /// Which field was corrected (`notes`, `aftercare`, ...), a key and not a label.
    var fieldKey: String

    // Encrypted at rest.
    var oldValue: String?
    var newValue: String?
    var reason: String?
}
