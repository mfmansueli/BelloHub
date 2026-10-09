//
//  TreatmentDraft.swift
//  BelloHub
//

import Foundation

/// What she has filled in so far, by field key. Free text, a choice and a number as typed; yes or no as
/// `RecordFieldEntry.yes` / `.no`; several options and a list of products as lines (`RecordFieldEntry.optionSeparator`).
/// A field she did not touch is absent, and stays empty in the record: nothing is guessed or filled in for her.
struct TreatmentDraft: Equatable, Sendable {
    var result: RecordResult?
    private(set) var values: [String: String] = [:]

    init(result: RecordResult? = nil, values: [String: String] = [:]) {
        self.result = result
        for (key, value) in values { set(value, for: key) }
    }

    func value(for key: String) -> String { values[key] ?? "" }

    /// Stores an answer; a blank one removes the field.
    mutating func set(_ value: String, for key: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { values[key] = nil } else { values[key] = value }
    }

    func lines(for key: String) -> [String] {
        value(for: key).components(separatedBy: RecordFieldEntry.optionSeparator)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    mutating func setLines(_ lines: [String], for key: String) {
        set(lines.joined(separator: RecordFieldEntry.optionSeparator), for: key)
    }

    /// Nothing worth saving: no result and every answer blank.
    var isEmpty: Bool { result == nil && values.isEmpty }
}
