//
//  DigitNormalizerTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("DigitNormalizer")
struct DigitNormalizerTests {
    @Test("Every digit system maps to ASCII, one to one", arguments: [
        ("٠١٢٣٤٥٦٧٨٩", "0123456789"),
        ("۰۱۲۳۴۵۶۷۸۹", "0123456789"),
        ("०१२३४५६७८९", "0123456789"),
        ("０１２３４５６７８９", "0123456789"),
        ("0123456789", "0123456789")
    ])
    func digits(input: String, expected: String) {
        #expect(DigitNormalizer.ascii(input) == expected)
    }

    @Test("Mixed text keeps its non-digits and converts the digits")
    func mixedText() {
        #expect(DigitNormalizer.ascii("+٩٦٦ ٥٠ abc ٧") == "+966 50 abc 7")
    }

    @Test("Arabic decimal and thousands separators become ASCII ones")
    func separators() {
        #expect(DigitNormalizer.ascii("١٬٢٣٤٫٥٠") == "1,234.50")
    }

    @Test("digitsOnly drops everything that is not a digit after normalizing")
    func digitsOnly() {
        #expect(DigitNormalizer.digitsOnly("(٠١١) ٩١٢٣٤-५६७८") == "011912345678")
        #expect(DigitNormalizer.digitsOnly("no digits") == "")
        #expect(DigitNormalizer.digitsOnly("") == "")
    }
}
