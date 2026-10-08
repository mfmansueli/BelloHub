//
//  PriceInput.swift
//  BelloHub
//

import Foundation

/// What she typed in a price field, read the way her language writes numbers ("120,50" in Brazil, "120.50" in the
/// United States, Arabic-Indic digits in Arabic).
enum PriceInput: Equatable {
    /// Nothing typed: the price is optional.
    case empty
    case value(Decimal)
    case invalid

    init(_ text: String, locale: Locale) {
        let trimmed = DigitNormalizer.ascii(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self = .empty
            return
        }
        if let value = Decimal(string: trimmed, locale: locale), value >= 0 {
            self = .value(value)
        } else {
            self = .invalid
        }
    }

    /// The amount to store, or nil when there is none.
    var amount: Decimal? {
        if case .value(let value) = self { value } else { nil }
    }

    var isInvalid: Bool { self == .invalid }
}
