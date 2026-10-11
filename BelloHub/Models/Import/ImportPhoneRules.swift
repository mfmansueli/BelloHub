//
//  ImportPhoneRules.swift
//  BelloHub
//

import Foundation

/// Which phone number of a candidate becomes the client's, and how a spreadsheet cell with several numbers is read.
/// Pure: the normalizer and the region come in, so the same table of numbers is tested for every market.
enum ImportPhoneRules {
    enum Pick: Equatable, Sendable {
        /// The source has no number: the client is imported without one (the phone is optional).
        case none
        case valid(String)
        /// A number is there but none of them is a phone number: the row is malformed, never silently dropped.
        case invalid
    }

    /// The first mobile number that normalizes, else the first number that normalizes. Blank numbers are ignored.
    static func pick(from numbers: [ImportPhoneNumber], normalizer: PhoneNormalizer, region: RegionPreset) -> Pick {
        let present = numbers.filter { !$0.raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !present.isEmpty else { return .none }
        var firstValid: String?
        for number in present {
            guard case .success(let e164) = normalizer.normalize(number.raw, defaultRegion: region) else { continue }
            if number.isMobile { return .valid(e164) }
            if firstValid == nil { firstValid = e164 }
        }
        return firstValid.map { .valid($0) } ?? .invalid
    }

    /// The numbers written in one spreadsheet cell: "11 98765-4321 / 11 3333-4444" is two numbers. A phone number has
    /// no slash, semicolon, bar, comma or line break, so those always separate numbers.
    static func numbers(inCell cell: String) -> [ImportPhoneNumber] {
        cell.split(whereSeparator: { $0.isNewline || "/;|,".contains($0) })
            .map { ImportPhoneNumber(String($0)) }
    }

    /// Whether a value looks like a phone number: 7 to 15 digits and nothing but the punctuation phones use.
    /// Used to find the phone column of a file whose header says nothing.
    static func looksLikePhone(_ value: String) -> Bool {
        let ascii = DigitNormalizer.ascii(value)
        let allowed = ascii.allSatisfy { $0.isNumber || "+-().  /\u{00A0}\u{202F}".contains($0) }
        guard allowed else { return false }
        return (7...15).contains(ascii.filter { $0.isASCII && $0.isNumber }.count)
    }
}
