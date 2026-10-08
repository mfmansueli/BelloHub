//
//  Consent.swift
//  BelloHub
//

import Foundation

/// A signed consent for one purpose. The text is referenced by `textVersion` and `localeID`; the signature is
/// encrypted at rest.
struct Consent: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var clientID: UUID
    var kind: ConsentKind
    var signedAt: Date
    var textVersion: String
    var localeID: String

    // Encrypted at rest.
    var typedSignature: String?
    var signatureImage: Data?
}
