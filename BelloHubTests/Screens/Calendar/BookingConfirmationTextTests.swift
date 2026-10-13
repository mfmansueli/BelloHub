//
//  BookingConfirmationTextTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BookingConfirmationText")
struct BookingConfirmationTextTests {
    private let ana = Client(name: "Ana Costa", phoneE164: "+5511981234410", createdAt: TestClock.days(-200))
    private let fridayMorning = TestClock.date("2026-10-02 10:00")

    private func formatters(_ localization: AppLocalization = .en) -> Formatters {
        Formatters(locale: localization.locale, timeZone: TestClock.saoPaulo, currencyCode: "BRL")
    }

    private var location: BusinessLocation {
        BusinessLocation(
            street: "Rua Augusta 1200",
            postalCode: "01304-001",
            city: "São Paulo",
            countryCode: "BR",
            directions: "2º andar, sala 4"
        )
    }

    @Test("Confirmation text includes client first name, service, date, time, address, link and business")
    func confirmationTextComplete() {
        let text = BookingConfirmationText.text(for: BookingConfirmationText.Input(
            client: ana,
            serviceName: "Glow Facial",
            startsAt: fridayMorning,
            link: "https://bellohub.app/maria",
            location: location,
            businessName: "Studio Bella",
            confirmReply: nil,
            localization: .en,
            formatters: formatters(.en)
        ))

        #expect(text.contains("Hi Ana!"))
        #expect(text.contains("Glow Facial"))
        #expect(text.contains("10:00"))
        #expect(text.contains("Rua Augusta 1200"))
        #expect(text.contains("São Paulo 01304-001"))
        #expect(text.contains("2º andar, sala 4"))
        #expect(text.contains("Google Maps"))
        #expect(text.contains("Apple Maps"))
        #expect(text.contains("https://bellohub.app/maria"))
        #expect(text.contains("Studio Bella"))
        #expect(!text.contains("Reply YES"))
        #expect(!text.contains("{"))
    }

    @Test("Confirmation text removes address token cleanly when no location is configured")
    func confirmationTextWithoutLocation() {
        let text = BookingConfirmationText.text(for: BookingConfirmationText.Input(
            client: ana,
            serviceName: "Glow Facial",
            startsAt: fridayMorning,
            link: "https://bellohub.app/maria",
            location: nil,
            confirmReply: nil,
            localization: .en,
            formatters: formatters(.en)
        ))

        #expect(text.contains("Hi Ana!"))
        #expect(text.contains("Glow Facial"))
        #expect(!text.contains("{address}"))
        #expect(text.contains("https://bellohub.app/maria"))
    }

    @Test("A custom edited quick reply text is respected")
    func customReplyText() {
        let customReply = QuickReply(
            id: BuiltInQuickReply.confirm.id,
            builtInKey: BuiltInQuickReply.confirm.rawValue,
            title: "Confirm appointment",
            text: "Hello {name}, your appointment for {service} is set for {date} at {time}!\n{address}\nSee you soon!",
            position: 0,
            updatedAt: TestClock.now
        )

        let text = BookingConfirmationText.text(for: BookingConfirmationText.Input(
            client: ana,
            serviceName: "Deep Cleansing",
            startsAt: fridayMorning,
            link: nil,
            location: location,
            confirmReply: customReply,
            localization: .en,
            formatters: formatters(.en)
        ))

        #expect(text.contains("Hello Ana, your appointment for Deep Cleansing is set for"))
        #expect(text.contains("Rua Augusta 1200"))
        #expect(text.contains("See you soon!"))
    }
}
