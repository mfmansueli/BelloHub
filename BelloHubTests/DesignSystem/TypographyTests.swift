//
//  TypographyTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Typography")
struct TypographyTests {
    @Test("Arabic and Hindi get the 1.15 line height multiplier, other languages do not",
          arguments: [
              ("ar", 1.15), ("hi", 1.15),
              ("pt", 1), ("es", 1), ("en", 1), ("it", 1), ("fr", 1), ("de", 1), ("tr", 1), ("id", 1)
          ])
    func multiplier(code: String, expected: Double) {
        let language = Locale.Language(identifier: code)

        #expect(Double(Typography.lineHeightMultiplier(for: language)) == expected)
    }

    @Test("Regional variants follow their language")
    func regionalVariants() {
        #expect(Typography.lineHeightMultiplier(for: Locale(identifier: "ar_AE").language) == 1.15)
        #expect(Typography.lineHeightMultiplier(for: Locale(identifier: "hi_IN").language) == 1.15)
        #expect(Typography.lineHeightMultiplier(for: Locale(identifier: "pt_BR").language) == 1)
    }

    @Test("Extra line spacing scales with the font size and is zero for Latin text")
    func lineSpacing() {
        let arabic = Locale.Language(identifier: "ar")
        let portuguese = Locale.Language(identifier: "pt")

        #expect(Typography.lineSpacing(forSize: 17, language: portuguese) == 0)
        #expect(abs(Typography.lineSpacing(forSize: 20, language: arabic) - 3.6) < 0.001)
        let small = Typography.lineSpacing(forSize: 20, language: arabic)
        let large = Typography.lineSpacing(forSize: 40, language: arabic)
        #expect(large > small)
    }

    @Test("A language with no code falls back to the Latin multiplier")
    func unknownLanguage() {
        #expect(Typography.lineHeightMultiplier(for: Locale.Language(identifier: "")) == 1)
    }
}
