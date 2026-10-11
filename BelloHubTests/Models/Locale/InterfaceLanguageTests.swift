//
//  InterfaceLanguageTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("InterfaceLanguage")
struct InterfaceLanguageTests {
    @Test("Storage round-trips every choice; anything unknown is the iPhone's language")
    func storage() {
        #expect(InterfaceLanguage(storageValue: "system") == .system)
        #expect(InterfaceLanguage(storageValue: nil) == .system)
        #expect(InterfaceLanguage(storageValue: "xx") == .system)
        for localization in AppLocalization.allCases {
            let choice = InterfaceLanguage.fixed(localization)
            #expect(InterfaceLanguage(storageValue: choice.storageValue) == choice)
        }
    }

    @Test("Same as iPhone takes the localization iOS chose for the bundle", arguments: AppLocalization.allCases)
    func systemFollowsTheBundle(localization: AppLocalization) {
        let resolved = InterfaceLanguage.system.localization(bundleLocalizations: [localization.rawValue, "en"])
        #expect(resolved == localization)
    }

    @Test("A language the product does not speak falls back to English")
    func unknownLanguageFallsBack() {
        #expect(InterfaceLanguage.system.localization(bundleLocalizations: ["ja"]) == .en)
        #expect(InterfaceLanguage.system.localization(bundleLocalizations: []) == .en)
    }

    @Test("A fixed choice ignores the bundle")
    func fixedIgnoresBundle() {
        #expect(InterfaceLanguage.fixed(.ptPT).localization(bundleLocalizations: ["en"]) == .ptPT)
    }

    @Test(
        "The interface locale always resolves back to its localization, from any iPhone locale",
        arguments: AppLocalization.allCases
    )
    func localeResolvesBack(localization: AppLocalization) {
        let devices = ["en_US", "pt_BR", "pt_PT", "de_DE", "ar_SA", "ja_JP", "en_GB", "es_AR", "fr_CA", "hi_IN"]
        for device in devices {
            let locale = InterfaceLanguage.locale(for: localization, device: Locale(identifier: device))
            #expect(AppLocalization(resolving: locale) == localization, "\(localization.rawValue) on \(device)")
        }
    }

    @Test("Portuguese (Brazil) on an iPhone in Portugal stays Brazilian (the old pt_PT mix)")
    func brazilianInPortugal() {
        let locale = InterfaceLanguage.locale(for: .ptBR, device: Locale(identifier: "pt_PT"))
        #expect(locale.identifier == "pt_BR")
    }

    @Test("The iPhone's own locale is kept when it already speaks the interface language")
    func keepsDeviceLocale() {
        let device = Locale(identifier: "de_AT")
        #expect(InterfaceLanguage.locale(for: .de, device: device) == device)
        #expect(InterfaceLanguage.locale(for: .fr, device: Locale(identifier: "de_AT")).identifier == "fr_AT")
    }

    @Test("English (US) on an iPhone in the UK is American, not British")
    func americanInBritain() {
        #expect(AppLocalization(resolving: InterfaceLanguage.locale(for: .en, device: Locale(identifier: "en_GB")))
                == .en)
    }

    @Test("A per-app language set in iOS Settings after her choice wins")
    func iosSettingsWins() {
        let stored = InterfaceLanguage.fixed(.de)
        #expect(InterfaceLanguage.reconciled(stored: stored, appDomainLanguages: ["de"], written: ["de"]) == stored)
        #expect(InterfaceLanguage.reconciled(stored: stored, appDomainLanguages: ["pt-PT"], written: ["de"])
                == .fixed(.ptPT))
        #expect(InterfaceLanguage.reconciled(stored: stored, appDomainLanguages: nil, written: ["de"]) == .system)
        #expect(InterfaceLanguage.reconciled(stored: .system, appDomainLanguages: nil, written: nil) == .system)
        #expect(InterfaceLanguage.reconciled(stored: .system, appDomainLanguages: ["ja"], written: nil) == .system)
    }

    @Test("Only a fixed choice writes AppleLanguages")
    func appleLanguages() {
        #expect(InterfaceLanguage.system.appleLanguages == nil)
        #expect(InterfaceLanguage.fixed(.ptBR).appleLanguages == ["pt-BR"])
    }
}
