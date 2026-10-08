//
//  ConsentSensitiveFields.swift
//  BelloHub
//

import Foundation

/// The encrypted part of a `Consent`.
struct ConsentSensitiveFields: Codable, Equatable, Sendable {
    var typedSignature: String?
    var signatureImage: Data?

    init(_ consent: Consent) {
        typedSignature = consent.typedSignature
        signatureImage = consent.signatureImage
    }
}
