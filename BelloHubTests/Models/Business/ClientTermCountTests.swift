//
//  ClientTermCountTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// `ClientTerm.countText` picks the noun by the language's own plural rules (docs/07-LOCALIZATION.md section 2.1). The
/// expectations name only the noun, never the digits, because the digits are the locale's (Arabic-Indic in Arabic).
@Suite("ClientTerm counts")
struct ClientTermCountTests {
    @Test("Every term has a counted form in every localization, never the raw key", arguments: AppLocalization.allCases)
    func everyLocalization(localization: AppLocalization) {
        for term in ClientTerm.allCases {
            for count in [0, 1, 2, 3, 11, 100] {
                let text = term.countText(count, in: localization.locale)
                #expect(!text.isEmpty && !text.hasPrefix("term."), "\(term) \(count) in \(localization)")
            }
        }
    }

    @Test("English takes the singular for one only")
    func english() {
        let locale = Locale(identifier: "en")
        #expect(ClientTerm.client.countText(1, in: locale) == "1 client")
        #expect(ClientTerm.client.countText(12, in: locale) == "12 clients")
        #expect(ClientTerm.guest.countText(0, in: locale) == "0 guests")
    }

    @Test("German counts people, because the collective Kundschaft cannot follow a number")
    func german() {
        let locale = Locale(identifier: "de")
        #expect(ClientTerm.client.countText(1, in: locale) == "1 Person")
        #expect(ClientTerm.client.countText(12, in: locale) == "12 Personen")
        #expect(!ClientTerm.client.countText(12, in: locale).contains("Kundschaft"))
    }

    @Test("French and Brazilian Portuguese treat zero as singular")
    func zeroIsSingular() {
        #expect(ClientTerm.client.countText(0, in: Locale(identifier: "fr")) == "0 client")
        #expect(ClientTerm.client.countText(0, in: Locale(identifier: "pt-BR")) == "0 cliente")
        #expect(ClientTerm.client.countText(2, in: Locale(identifier: "pt-BR")) == "2 clientes")
    }

    @Test("Arabic uses its six forms: dual, plural for 3 to 10 and the singular accusative from 11")
    func arabic() {
        let locale = Locale(identifier: "ar")
        #expect(ClientTerm.client.countText(1, in: locale) == "عميل واحد")
        #expect(ClientTerm.client.countText(2, in: locale) == "عميلان")
        #expect(ClientTerm.client.countText(3, in: locale).hasSuffix("عملاء"))
        #expect(ClientTerm.client.countText(11, in: locale).hasSuffix("عميلًا"))
        #expect(ClientTerm.client.countText(100, in: locale).hasSuffix(" عميل"))
    }

    @Test("Turkish, Hindi and Indonesian keep the noun unchanged after a number")
    func invariantNouns() {
        #expect(ClientTerm.client.countText(5, in: Locale(identifier: "tr")).hasSuffix("müşteri"))
        #expect(ClientTerm.client.countText(5, in: Locale(identifier: "id")).hasSuffix("klien"))
        #expect(ClientTerm.client.countText(5, in: Locale(identifier: "hi")).hasSuffix("क्लाइंट"))
    }
}
