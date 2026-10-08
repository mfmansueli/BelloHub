//
//  PhoneFormatter.swift
//  BelloHub
//

import Foundation

/// Display formatting of an E.164 number from the region's patterns in `regions.json`. Numbers are
/// always shown left-to-right: wrap the result with `BidiIsolate.wrapLeftToRight` inside right-to-left text.
struct PhoneFormatter: Sendable {
    let catalog: RegionCatalog

    /// `+55 (11) 91234-5678`. An unknown country keeps the digits after the plus, in groups of three.
    func international(_ e164: String) -> String {
        let digits = DigitNormalizer.digitsOnly(e164)
        guard let region = catalog.preset(matchingInternationalDigits: digits) else {
            return "+" + Self.group(digits, size: 3)
        }
        let national = String(digits.dropFirst(region.callingCode.count))
        return "+\(region.callingCode) \(format(national: national, region: region))"
    }

    /// The number as people in the region write it, without the country code.
    func national(_ e164: String) -> String {
        let digits = DigitNormalizer.digitsOnly(e164)
        guard let region = catalog.preset(matchingInternationalDigits: digits) else { return international(e164) }
        return format(national: String(digits.dropFirst(region.callingCode.count)), region: region)
    }

    private func format(national: String, region: RegionPreset) -> String {
        guard let pattern = region.phonePatterns[String(national.count)] else {
            return Self.group(national, size: 3)
        }
        var result = ""
        var digits = national.makeIterator()
        for character in pattern {
            if character == "#" {
                guard let digit = digits.next() else { break }
                result.append(digit)
            } else {
                result.append(character)
            }
        }
        return result
    }

    private static func group(_ digits: String, size: Int) -> String {
        stride(from: 0, to: digits.count, by: size)
            .map { start -> String in
                let begin = digits.index(digits.startIndex, offsetBy: start)
                let end = digits.index(begin, offsetBy: size, limitedBy: digits.endIndex) ?? digits.endIndex
                return String(digits[begin..<end])
            }
            .joined(separator: " ")
    }
}
