//
//  DigitNormalizer.swift
//  BelloHub
//

import Foundation

/// Turns the digits of any script into ASCII digits before data is stored (phones, codes, prices typed
/// by the user), because the keyboard of an Arabic or Hindi user types her own digits. The UI shows
/// numbers in the locale's digits (Foundation chooses); this is only for data that carries meaning.
enum DigitNormalizer {
    /// First code point of each ten-digit block that maps to 0 through 9.
    private static let zeroes: [UInt32] = [
        0x0660, // Arabic-Indic
        0x06F0, // Extended Arabic-Indic (Persian, Urdu)
        0x0966, // Devanagari
        0xFF10 // Fullwidth
    ]

    static func ascii(_ text: String) -> String {
        var result = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if let digit = digitValue(of: scalar) {
                result.append(Unicode.Scalar(UInt32(48 + digit)) ?? scalar)
            } else if scalar.value == 0x066B {
                result.append(".") // Arabic decimal separator
            } else if scalar.value == 0x066C {
                result.append(",") // Arabic thousands separator
            } else {
                result.append(scalar)
            }
        }
        return String(result)
    }

    /// Only the ASCII digits of `text`, after normalizing every other script's digits.
    static func digitsOnly(_ text: String) -> String {
        ascii(text).filter { $0.isASCII && $0.isNumber }
    }

    private static func digitValue(of scalar: Unicode.Scalar) -> Int? {
        for zero in zeroes where scalar.value >= zero && scalar.value < zero + 10 {
            return Int(scalar.value - zero)
        }
        return nil
    }
}
