//
//  AppLocalizationTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AppLocalization")
struct AppLocalizationTests {
    @Test("There are fourteen localizations and only Arabic is right-to-left")
    func fourteenLocalizations() {
        #expect(AppLocalization.allCases.count == 14)
        #expect(AppLocalization.allCases.filter(\.isRightToLeft) == [.ar])
    }

    @Test("Every localization is in the app bundle, so the String Catalog languages ship")
    func localizationsShip() {
        let shipped = Set(Bundle.main.localizations)

        for localization in AppLocalization.allCases {
            #expect(shipped.contains(localization.rawValue), "\(localization.rawValue) is not in the bundle")
        }
    }

    struct ResolutionCase: Sendable {
        let language: String
        let region: String?
        let expected: AppLocalization

        init(_ language: String, _ region: String?, _ expected: AppLocalization) {
            self.language = language
            self.region = region
            self.expected = expected
        }
    }

    /// The resolution cases listed in docs/07-LOCALIZATION.md section 2.2.
    static let resolutionCases: [ResolutionCase] = [
        ResolutionCase("pt", "BR", .ptBR),
        ResolutionCase("pt", nil, .ptBR),
        ResolutionCase("pt", "PT", .ptPT),
        ResolutionCase("pt", "AO", .ptPT),
        ResolutionCase("pt", "MZ", .ptPT),
        ResolutionCase("es", "ES", .es),
        ResolutionCase("es", nil, .es),
        ResolutionCase("es", "MX", .esMX),
        ResolutionCase("es", "US", .esMX),
        ResolutionCase("es", "AR", .es419),
        ResolutionCase("es", "CO", .es419),
        ResolutionCase("es", "CL", .es419),
        ResolutionCase("es", "PE", .es419),
        ResolutionCase("es", "419", .es419),
        ResolutionCase("en", "US", .en),
        ResolutionCase("en", nil, .en),
        ResolutionCase("en", "CA", .en),
        ResolutionCase("en", "GB", .enGB),
        ResolutionCase("en", "IE", .enGB),
        ResolutionCase("en", "AU", .enGB),
        ResolutionCase("en", "IN", .enGB),
        ResolutionCase("en", "ZA", .enGB),
        ResolutionCase("en", "NZ", .enGB),
        ResolutionCase("fr", "FR", .fr),
        ResolutionCase("fr", "BE", .fr),
        ResolutionCase("fr", "CA", .fr),
        ResolutionCase("fr", "CH", .fr),
        ResolutionCase("de", "DE", .de),
        ResolutionCase("de", "AT", .de),
        ResolutionCase("de", "CH", .de),
        ResolutionCase("it", "IT", .it),
        ResolutionCase("tr", "TR", .tr),
        ResolutionCase("id", "ID", .id),
        ResolutionCase("hi", "IN", .hi),
        ResolutionCase("ar", "SA", .ar),
        ResolutionCase("ar", "AE", .ar),
        ResolutionCase("ar", "EG", .ar)
    ]

    @Test("The business localization follows device language and region", arguments: resolutionCases)
    func resolution(_ testCase: ResolutionCase) {
        let resolved = AppLocalization.resolve(languageCode: testCase.language, regionCode: testCase.region)

        #expect(resolved == testCase.expected)
    }

    @Test("A language the product does not speak resolves to nothing, so the caller can pick English")
    func unsupportedLanguage() {
        #expect(AppLocalization.resolve(languageCode: "nl", regionCode: "NL") == nil)
        #expect(AppLocalization.resolve(languageCode: "ja", regionCode: "JP") == nil)
    }

    @Test("Preferred languages are tried in order and a missing region falls back to the device region")
    func preferredLanguages() {
        #expect(AppLocalization.resolve(preferredLanguages: ["nl-NL", "pt-BR", "en"], regionCode: "NL") == .ptBR)
        #expect(AppLocalization.resolve(preferredLanguages: ["es"], regionCode: "AR") == .es419)
        #expect(AppLocalization.resolve(preferredLanguages: ["en"], regionCode: "AU") == .enGB)
        #expect(AppLocalization.resolve(preferredLanguages: ["ja"], regionCode: "JP") == nil)
    }

    @Test("Derived localizations share their parent's language code")
    func languageCodes() {
        #expect(AppLocalization.es419.languageCode == "es")
        #expect(AppLocalization.enGB.languageCode == "en")
        #expect(AppLocalization.ptPT.languageCode == "pt")
    }

    @Test("Every localization has a native name and a parseable locale")
    func namesAndLocales() {
        for localization in AppLocalization.allCases {
            #expect(!localization.nativeName.isEmpty)
            #expect(localization.locale.language.languageCode?.identifier == localization.languageCode)
        }
    }
}
