//
//  HealthForm.swift
//  BelloHub
//

import Foundation

/// A client's health history and the version of the form it answers. Arrives from the sealed mailbox (the client
/// filled it in her browser) or is entered by the professional. Everything below `importedFromItemID` is
/// encrypted at rest.
struct HealthForm: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var clientID: UUID
    var formVersion: Int
    var filledBy: HealthFiller
    var isForMinor: Bool
    var signedAt: Date?
    /// The mailbox item this came from, so importing the same envelope twice never duplicates it.
    var importedFromItemID: String?

    // Encrypted at rest.
    var answers: [String: HealthAnswer]
    var signatureImage: Data?
    var guardianName: String?
    var minorName: String?
}
