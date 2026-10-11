//
//  WaitlistOfferMessageTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("WaitlistOfferMessage")
struct WaitlistOfferMessageTests {
    private func input() throws -> WaitlistOfferMessage.Input {
        WaitlistOfferMessage.Input(
            personName: "Bia Souza", serviceName: "Glow Facial", startsAt: TestClock.date("2026-10-03 15:00"),
            heldUntil: TestClock.date("2026-10-01 18:00"),
            link: try #require(URL(string: "https://bellohub.app/maria/time?offer=KEY123"))
        )
    }

    private func text(_ localization: AppLocalization) throws -> String {
        WaitlistOfferMessage.text(
            try input(), localization: localization,
            formatters: Formatters(locale: localization.locale, timeZone: TestClock.saoPaulo, currencyCode: "BRL")
        )
    }

    @Test("The offer names the person, the time and the hold, with the full link on its own line")
    func english() throws {
        let message = try text(.en).replacingOccurrences(of: "\u{202F}", with: " ")
        #expect(message == """
            Hi Bia! A time just opened for Glow Facial on Saturday, October 3 at 3:00 PM. \
            It is yours if you confirm by Thursday, October 1, 6:00 PM:
            https://bellohub.app/maria/time?offer=KEY123
            """)
    }

    @Test("Every localization has the text, the values and the link last, alone on its line",
        arguments: AppLocalization.allCases)
    func everyLocalization(localization: AppLocalization) throws {
        let message = try text(localization)
        #expect(message.hasSuffix("\nhttps://bellohub.app/maria/time?offer=KEY123"), "\(localization.rawValue)")
        #expect(message.contains("Bia") && message.contains("Glow Facial"))
        #expect(!message.contains("waitlist.") && !message.contains("%"))
    }
}
