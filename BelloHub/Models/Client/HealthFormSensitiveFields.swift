//
//  HealthFormSensitiveFields.swift
//  BelloHub
//

import Foundation

/// The encrypted part of a `HealthForm`.
struct HealthFormSensitiveFields: Codable, Equatable, Sendable {
    var answers: [String: HealthAnswer]
    var signatureImage: Data?
    var guardianName: String?
    var minorName: String?

    init(_ form: HealthForm) {
        answers = form.answers
        signatureImage = form.signatureImage
        guardianName = form.guardianName
        minorName = form.minorName
    }
}
