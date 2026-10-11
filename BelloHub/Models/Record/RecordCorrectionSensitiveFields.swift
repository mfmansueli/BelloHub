//
//  RecordCorrectionSensitiveFields.swift
//  BelloHub
//

/// The encrypted part of a `RecordCorrection`.
struct RecordCorrectionSensitiveFields: Codable, Equatable, Sendable {
    var oldValue: String?
    var newValue: String?
    var reason: String?

    init(_ correction: RecordCorrection) {
        oldValue = correction.oldValue
        newValue = correction.newValue
        reason = correction.reason
    }
}
