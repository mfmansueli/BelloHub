//
//  FormattersTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Formatters")
struct FormattersTests {
    /// 2026-10-01 17:30 UTC, a Thursday: 14:30 in São Paulo, 18:30 in Lisbon (summer time) and
    /// 11:30 in Mexico City (UTC-6, no daylight saving since 2022).
    private static let instant = Date(timeIntervalSince1970: 1_790_875_800)

    private static func formatters(_ id: String, zone: String = "America/Sao_Paulo", currency: String = "BRL")
        -> Formatters {
        Formatters(locale: Locale(identifier: id), timeZone: TimeZone(identifier: zone) ?? .gmt, currencyCode: currency)
    }

    // MARK: - Expected values come from Foundation, never from memory (D25)

    @Test("Money is the Foundation currency style in the reader's locale, for every localization",
          arguments: AppLocalization.allCases)
    func moneyMatchesFoundation(localization: AppLocalization) {
        let formatters = Self.formatters(localization.rawValue, currency: "EUR")
        let expected = Decimal(1234.5).formatted(Decimal.FormatStyle.Currency(code: "EUR").locale(localization.locale))

        #expect(formatters.money(1234.5) == expected)
    }

    @Test("Times and dates match Foundation in the business time zone, for every localization",
          arguments: AppLocalization.allCases)
    func timeAndDateMatchFoundation(localization: AppLocalization) {
        let zone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = localization.locale
        calendar.timeZone = zone
        let formatters = Self.formatters(localization.rawValue)
        let timeStyle = Date.FormatStyle(locale: localization.locale, calendar: calendar, timeZone: zone)
            .hour().minute()
        let dateStyle = Date.FormatStyle(locale: localization.locale, calendar: calendar, timeZone: zone)
            .weekday(.wide).day().month(.wide)

        #expect(formatters.time(Self.instant) == Self.instant.formatted(timeStyle))
        #expect(formatters.weekdayDayMonth(Self.instant) == Self.instant.formatted(dateStyle))
    }

    // MARK: - Hand-verified quirks (docs/07-LOCALIZATION.md section 2.4)

    @Test("Spanish and European Portuguese do not group four-digit numbers: 1234,50 €")
    func spainAndPortugalDoNotGroupFourDigits() {
        #expect(Self.formatters("es_ES", currency: "EUR").money(1234.5) == "1234,50\u{00A0}€")
        #expect(Self.formatters("pt_PT", currency: "EUR").money(1234.5) == "1234,50\u{00A0}€")
    }

    @Test("French groups with a narrow no-break space and puts the euro after a no-break space")
    func french() {
        #expect(Self.formatters("fr_FR", currency: "EUR").money(1234.5) == "1\u{202F}234,50\u{00A0}€")
    }

    @Test("German writes 1.234,50 € and Turkish ₺1.234,50")
    func germanAndTurkish() {
        #expect(Self.formatters("de_DE", currency: "EUR").money(1234.5) == "1.234,50\u{00A0}€")
        #expect(Self.formatters("tr_TR", currency: "TRY").money(1234.5) == "₺1.234,50")
    }

    @Test("Brazilian Portuguese writes R$ 1.234,50 with a no-break space")
    func brazil() {
        #expect(Self.formatters("pt_BR").money(1234.5) == "R$\u{00A0}1.234,50")
    }

    @Test("Hindi groups in lakhs and US English in thousands")
    func hindiAndEnglish() {
        #expect(Self.formatters("hi_IN", currency: "INR").money(123_456) == "₹1,23,456.00")
        #expect(Self.formatters("en_US", currency: "USD").money(1234.5) == "$1,234.50")
    }

    @Test("The same instant reads differently in each business time zone")
    func businessTimeZone() {
        let saoPaulo = Self.formatters("pt_BR", zone: "America/Sao_Paulo")
        let lisbon = Self.formatters("pt_PT", zone: "Europe/Lisbon")
        let mexico = Self.formatters("es_MX", zone: "America/Mexico_City")

        #expect(saoPaulo.time(Self.instant, use24Hour: true) == "14:30")
        #expect(lisbon.time(Self.instant, use24Hour: true) == "18:30")
        #expect(mexico.time(Self.instant, use24Hour: true) == "11:30")
    }

    @Test("The 12/24 hour override beats the locale default")
    func clockOverride() {
        let american = Self.formatters("en_US", zone: "America/New_York")

        #expect(american.time(Self.instant, use24Hour: true) == "13:30")
        #expect(american.time(Self.instant, use24Hour: false) == "1:30 PM")
        #expect(Self.formatters("pt_BR").time(Self.instant, use24Hour: false).hasPrefix("2:30"))
        #expect(Self.formatters("pt_BR").time(Self.instant) == "14:30")
    }

    @Test("A list uses the locale's conjunction")
    func lists() {
        #expect(Self.formatters("en_US").list(["Ana", "Bia", "Carla"]) == "Ana, Bia, and Carla")
        #expect(Self.formatters("pt_BR").list(["Ana", "Bia", "Carla"]) == "Ana, Bia e Carla")
        #expect(Self.formatters("de_DE").list(["Ana", "Bia", "Carla"]) == "Ana, Bia und Carla")
    }

    @Test("A duration in minutes is split into hours and minutes")
    func durations() {
        let english = Self.formatters("en_US")

        #expect(english.duration(minutes: 90) == "1 hr, 30 min")
        #expect(english.duration(minutes: 45) == "45 min")
    }

    @Test("Arabic regions that use Arabic-Indic digits get them from Foundation, not from us")
    func arabicDigits() {
        let egypt = Self.formatters("ar_EG", currency: "EGP")
        let uae = Self.formatters("ar_AE", currency: "AED")

        #expect(egypt.number(123) == Int(123).formatted(.number.locale(Locale(identifier: "ar_EG"))))
        #expect(uae.number(123) == Int(123).formatted(.number.locale(Locale(identifier: "ar_AE"))))
    }

    @Test("Calendar is Gregorian everywhere, also for Arabic and Hindi")
    func gregorianEverywhere() {
        for id in ["ar_SA", "hi_IN", "th_TH"] {
            #expect(Self.formatters(id).calendar.identifier == .gregorian)
        }
    }

    @Test("A first-weekday override reaches the calendar")
    func firstWeekdayOverride() {
        let formatters = Formatters(locale: Locale(identifier: "en_US"), timeZone: .gmt, currencyCode: "USD",
                                    firstWeekday: 2)

        #expect(formatters.calendar.firstWeekday == 2)
    }
}
