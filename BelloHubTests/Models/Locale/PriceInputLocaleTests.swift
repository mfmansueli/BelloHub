//
//  PriceInputLocaleTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// How a price with a fraction is read in each language: the cases the first `PriceInput` suite does not cover.
@Suite("PriceInput in each language")
struct PriceInputLocaleTests {
    @Test("A price with a fraction is read as the language writes it", arguments: [
        ("120.50", "en_US", "120.5"), ("1,234.50", "en_US", "1234.5"), ("120,50", "pt_BR", "120.5"),
        ("1.234,50", "pt_BR", "1234.5"), ("120,50", "de_DE", "120.5"), ("1 234,50", "fr_FR", "1234.5"),
        ("١٢٠٫٥٠", "ar_SA", "120.5"), ("١٢٣٤٫٥", "ar_SA", "1234.5"), ("१२०.५०", "hi_IN", "120.5"),
        ("120,5", "es_ES", "120.5"), ("120", "tr_TR", "120")
    ])
    func fractions(text: String, localeID: String, expected: String) {
        let input = PriceInput(text, locale: Locale(identifier: localeID))
        #expect(input.amount == Decimal(string: expected))
    }

    @Test("A price written out by Foundation for a language is read back in the same language", arguments: [
        "en_US", "pt_BR", "pt_PT", "es_MX", "es_ES", "it_IT", "fr_FR", "de_DE", "tr_TR", "id_ID", "hi_IN", "ar_SA"
    ])
    func roundTrip(localeID: String) {
        let locale = Locale(identifier: localeID)
        for amount in [Decimal(string: "0.5"), Decimal(string: "70"), Decimal(string: "1234.75")].compactMap({ $0 }) {
            let text = amount.formatted(.number.locale(locale).grouping(.never))
            #expect(PriceInput(text, locale: locale).amount == amount, "\(text) in \(localeID)")
            let grouped = amount.formatted(.number.locale(locale))
            #expect(PriceInput(grouped, locale: locale).amount == amount, "\(grouped) in \(localeID)")
        }
    }

    @Test("Letters after the digits, two decimal marks and a sign are not prices", arguments: [
        "12abc", "1.2.3", "-5", "+5", "R$ 12", "1e5", ".", ","
    ])
    func invalid(text: String) {
        #expect(PriceInput(text, locale: Locale(identifier: "en_US")).isInvalid, "\(text)")
    }

    @Test("A mark that groups thousands in her language is not taken for the decimal point")
    func groupingIsNotDecimal() {
        let brazil = Locale(identifier: "pt_BR")
        #expect(PriceInput("12.50", locale: brazil).isInvalid, "would read as 1250, a hundred times what she meant")
        #expect(PriceInput("1.234", locale: brazil).amount == 1234)
        #expect(PriceInput("1.234,5", locale: brazil).amount == Decimal(string: "1234.5"))
        #expect(PriceInput("1,5", locale: Locale(identifier: "en_US")).isInvalid)
        #expect(PriceInput("12,34,567", locale: Locale(identifier: "hi_IN")).amount == 1_234_567)
    }
}
