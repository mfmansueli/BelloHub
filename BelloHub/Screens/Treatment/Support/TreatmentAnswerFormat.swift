//
//  TreatmentAnswerFormat.swift
//  BelloHub
//

import Foundation

/// How an answer is stored and how it reads: the stored forms are the same in the draft, the record and the review
/// (`RecordFieldEntry`), the reading forms are in her language. Pure, so the round trips are tested.
enum TreatmentAnswerFormat {
    /// The separate items of a multi-choice or products answer.
    static func items(_ value: String) -> [String] {
        value.components(separatedBy: RecordFieldEntry.optionSeparator)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func join(_ items: [String]) -> String {
        items.joined(separator: RecordFieldEntry.optionSeparator)
    }

    /// `items` with `item` added (when it is new, ignoring case) or removed (when it is already there).
    static func toggled(_ item: String, in items: [String]) -> [String] {
        if items.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
            return items.filter { $0.caseInsensitiveCompare(item) != .orderedSame }
        }
        return items + [item]
    }

    /// `items` with `item` added unless it is blank or already there (a product she typed twice).
    static func adding(_ item: String, to items: [String]) -> [String] {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !items.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return items }
        return items + [trimmed]
    }

    /// The answer as the card or the saved summary shows it. `yes` and `no` come from the caller (they are words in
    /// her language); a number gets its unit, a list is joined with the locale's own list style.
    static func display(
        _ value: String, input: TreatmentFormField.Input, yes: String, no: String, locale: Locale
    ) -> String {
        switch input {
        case .yesNo:
            return value == RecordFieldEntry.yes ? yes : (value == RecordFieldEntry.no ? no : value)
        case .multiChoice, .products:
            return items(value).formatted(.list(type: .and, width: .narrow).locale(locale))
        case .number(let unit):
            return unit.map { "\(value) \($0)" } ?? value
        case .text, .choice:
            return value
        }
    }

    /// A free-text field that holds one saved word per line (the technique, written by "+ Add"), trimmed and without
    /// empty lines.
    static func textLines(_ value: String) -> [String] {
        value.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
