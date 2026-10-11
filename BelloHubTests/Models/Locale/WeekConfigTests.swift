//
//  WeekConfigTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("WeekConfig")
struct WeekConfigTests {
    struct Case: Sendable {
        let region: String
        let language: String
        let firstWeekday: Int
        let use24Hour: Bool
    }

    /// The defaults listed in docs/07-LOCALIZATION.md section 2.4. 1 is Sunday, 2 is Monday.
    static let documented: [Case] = [
        Case(region: "US", language: "en", firstWeekday: 1, use24Hour: false),
        Case(region: "BR", language: "pt", firstWeekday: 1, use24Hour: true),
        Case(region: "MX", language: "es", firstWeekday: 1, use24Hour: false),
        Case(region: "ES", language: "es", firstWeekday: 2, use24Hour: true),
        Case(region: "PT", language: "pt", firstWeekday: 1, use24Hour: true),
        Case(region: "DE", language: "de", firstWeekday: 2, use24Hour: true),
        Case(region: "FR", language: "fr", firstWeekday: 2, use24Hour: true),
        Case(region: "IT", language: "it", firstWeekday: 2, use24Hour: true),
        Case(region: "GB", language: "en", firstWeekday: 2, use24Hour: true)
    ]

    @Test("The documented week start and clock defaults hold", arguments: documented)
    func documentedDefaults(testCase: Case) {
        let config = WeekConfig.defaults(forRegion: testCase.region, languageCode: testCase.language)

        #expect(config.firstWeekday == testCase.firstWeekday, "\(testCase.region) first weekday")
        #expect(config.use24Hour == testCase.use24Hour, "\(testCase.region) 24-hour clock")
    }

    @Test("Every preset region has a valid first weekday, taken from Foundation")
    func everyPresetHasAWeekStart() throws {
        for preset in try RegionCatalogTests.bundled().presets {
            let config = WeekConfig.defaults(forRegion: preset.code)
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "und_\(preset.code)")

            #expect((1...7).contains(config.firstWeekday), "\(preset.code)")
            #expect(config.firstWeekday == calendar.firstWeekday, "\(preset.code) differs from Foundation")
        }
    }
}
