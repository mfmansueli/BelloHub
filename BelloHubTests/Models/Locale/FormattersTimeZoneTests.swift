//
//  FormattersTimeZoneTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Formatters+TimeZone")
struct FormattersTimeZoneTests {
    private func name(_ zoneID: String, in localeID: String) -> String {
        let formatters = Formatters(
            locale: Locale(identifier: localeID), timeZone: TestClock.saoPaulo, currencyCode: "BRL"
        )
        return formatters.zoneName(TimeZone(identifier: zoneID) ?? .gmt, at: TestClock.now)
    }

    @Test("A zone reads as its city, in the reader's language")
    func cityInLanguage() {
        #expect(name("Europe/Rome", in: "en_US") == "Rome")
        #expect(name("Europe/Rome", in: "pt_BR") == "Roma")
        #expect(name("Europe/Rome", in: "de_DE") == "Rom")
        #expect(name("America/Sao_Paulo", in: "en_US") == "São Paulo")
        #expect(name("Asia/Kolkata", in: "en_US") == "Kolkata")
        #expect(name("Europe/Rome", in: "ar_SA") != "Rome", "Arabic names the city in Arabic")
    }

    @Test("A zone without a city reads as its offset, never as an unknown city")
    func offsetForZonesWithoutCity() {
        let etc = name("Etc/GMT+3", in: "en_US")
        #expect(etc.contains("GMT"))
        #expect(etc.contains("3"))
        #expect(!etc.localizedCaseInsensitiveContains("unknown"))
        #expect(!name("Etc/GMT+3", in: "pt_BR").localizedCaseInsensitiveContains("desconhecida"))
    }
}
