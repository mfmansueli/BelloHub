//
//  PriceInput.swift
//  BelloHub
//

import Foundation

/// What she typed in a price field, read the way her language writes numbers ("120,50" in Brazil, "120.50" in the
/// United States, Arabic-Indic digits and the Arabic decimal mark in Arabic). Used by every form that has a price
/// (the setup, the services, the add-ons).
///
/// The text is turned into plain digits first, then the language's own grouping mark is dropped and its decimal mark
/// becomes ".". It is not handed to `Decimal(string:locale:)`, which stops reading at the first character the locale
/// does not know: an Arabic "120٫50" typed on an Arabic keyboard came back as 120.
enum PriceInput: Equatable {
    /// Nothing typed: the price is optional.
    case empty
    case value(Decimal)
    case invalid

    init(_ text: String, locale: Locale) {
        let typed = DigitNormalizer.ascii(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else {
            self = .empty
            return
        }
        let decimalMark = Self.mark(locale.decimalSeparator, fallback: ".")
        let groupingMark = Self.mark(locale.groupingSeparator, fallback: ",")
        let plain = typed.unicodeScalars.filter { !CharacterSet.whitespaces.contains($0) && $0.value != 0x202F }
            .map(String.init).joined()
        // Only digits, grouped the way her language groups them (thousands, or the lakhs of Hindi) and with at most
        // one decimal mark: "12abc", "-5" and "12.50" in a language whose "." groups thousands are not prices. The
        // last one would read as 1250 if the mark were simply dropped, a hundred times the price she meant.
        let group = NSRegularExpression.escapedPattern(for: groupingMark)
        let decimal = NSRegularExpression.escapedPattern(for: decimalMark)
        let whole = "[0-9]+|[0-9]{1,3}(?:\(group)[0-9]{3})+|[0-9]{1,2}(?:\(group)[0-9]{2})*\(group)[0-9]{3}"
        let pattern = "^(?:\(whole))(?:\(decimal)[0-9]+)?$"
        guard groupingMark != decimalMark, plain.range(of: pattern, options: .regularExpression) != nil else {
            self = .invalid
            return
        }
        let number = plain.replacingOccurrences(of: groupingMark, with: "")
            .replacingOccurrences(of: decimalMark, with: ".")
        if let value = Decimal(string: number, locale: Locale(identifier: "en_US_POSIX")) {
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

    /// A mark of the locale as plain ASCII ("٫" is ".", the narrow no-break space of French is dropped by the caller).
    private static func mark(_ mark: String?, fallback: String) -> String {
        DigitNormalizer.ascii(mark ?? fallback)
    }
}
