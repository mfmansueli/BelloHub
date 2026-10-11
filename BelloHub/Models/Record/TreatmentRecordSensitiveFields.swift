//
//  TreatmentRecordSensitiveFields.swift
//  BelloHub
//

/// The encrypted part of a `TreatmentRecord`.
struct TreatmentRecordSensitiveFields: Codable, Equatable, Sendable {
    var notes: String?
    var technique: String?
    var productsUsed: [String]
    var resultDetail: String?
    var aftercare: String?
    var nextSessionSuggestion: String?
    var fieldEntries: [RecordFieldEntry]?

    init(_ record: TreatmentRecord) {
        notes = record.notes
        technique = record.technique
        productsUsed = record.productsUsed
        resultDetail = record.resultDetail
        aftercare = record.aftercare
        nextSessionSuggestion = record.nextSessionSuggestion
        fieldEntries = record.fieldEntries
    }
}
