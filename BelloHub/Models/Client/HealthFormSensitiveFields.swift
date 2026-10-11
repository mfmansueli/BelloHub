//
//  HealthFormSensitiveFields.swift
//  BelloHub
//

import Foundation

/// The encrypted part of a `HealthForm`.
struct HealthFormSensitiveFields: Codable, Equatable, Sendable {
    var answers: [String: HealthAnswer]
    var minorName: String?

    init(_ form: HealthForm) {
        answers = form.answers
        minorName = form.minorName
    }
}
