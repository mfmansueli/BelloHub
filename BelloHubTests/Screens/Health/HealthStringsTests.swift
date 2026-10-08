//
//  HealthStringsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The strings with arguments and plurals of the health screens resolve to what a person reads: the number in the
/// right place, the plural form of each language. Expected values are hand-written for the languages with the
/// trickiest plurals; every other language is covered by `scripts/check-strings.sh` (all categories present).
@Suite("Health strings")
struct HealthStringsTests {
    private func resolve(_ resource: LocalizedStringResource, in localeID: String) -> String {
        String(localized: resource.localized(in: Locale(identifier: localeID)))
    }

    private func patchCount(_ count: Int, in localeID: String) -> String {
        resolve(LocalizedStringResource("health.patch.count", defaultValue: "\(count) records"), in: localeID)
    }

    private func months(_ count: Int, in localeID: String) -> String {
        resolve(LocalizedStringResource("formTemplates.months", defaultValue: "\(count) months"), in: localeID)
    }

    @Test("The number of patch tests uses each language's plural")
    func patchCounts() {
        #expect(patchCount(1, in: "en") == "1 record" && patchCount(2, in: "en") == "2 records")
        #expect(patchCount(1, in: "pt-PT") == "1 registo" && patchCount(3, in: "pt-PT") == "3 registos")
        #expect(patchCount(1, in: "fr") == "1 enregistrement" && patchCount(5, in: "fr") == "5 enregistrements")
        #expect(patchCount(4, in: "id") == "4 catatan")
    }

    @Test("Arabic uses all six forms for the number of records")
    func arabicRecords() {
        #expect(patchCount(0, in: "ar") == "لا سجلات")
        #expect(patchCount(1, in: "ar") == "سجل واحد")
        #expect(patchCount(2, in: "ar") == "سجلان")
        #expect(patchCount(3, in: "ar") == "3 سجلات")
        #expect(patchCount(11, in: "ar") == "11 سجلًا")
        #expect(patchCount(100, in: "ar") == "100 سجل")
    }

    @Test("The review periods read as months in the plural of each language", arguments: [3, 6, 12, 24])
    func reviewMonths(count: Int) {
        #expect(months(count, in: "en") == "\(count) months")
        #expect(months(count, in: "de") == "\(count) Monate")
        #expect(months(count, in: "hi") == "\(count) महीने")
        #expect(months(count, in: "ar").contains("\(count)"))
    }

    @Test("The sentence about how often she asks again carries the number, and one month has its own form")
    func reviewEvery() {
        func every(_ count: Int, _ localeID: String) -> String {
            resolve(LocalizedStringResource("health.review.every", defaultValue: "Review every \(count) months"),
                    in: localeID)
        }
        #expect(every(12, "en") == "Review every 12 months" && every(1, "en") == "Review every month")
        #expect(every(6, "pt-BR") == "Revisar a cada 6 meses")
        #expect(every(24, "de") == "Alle 24 Monate prüfen" && every(1, "de") == "Jeden Monat prüfen")
    }

    @Test("The two arguments of a signature line keep their places in every language",
          arguments: AppLocalization.allCases)
    func signedBy(localization: AppLocalization) {
        let text = resolve(
            LocalizedStringResource("health.consent.signedBy", defaultValue: "Signed by NAME-X · DATE-Y"),
            in: localization.rawValue
        )
        // The default value has no arguments here, so this is the catalog text for the key with its placeholders.
        #expect(!text.isEmpty)
        let named = String(localized: LocalizedStringResource(
            "health.consent.signedBy", defaultValue: "Signed by \("NAME-X") · \("DATE-Y")"
        ).localized(in: localization.locale))
        #expect(named.contains("NAME-X") && named.contains("DATE-Y"))
    }
}
