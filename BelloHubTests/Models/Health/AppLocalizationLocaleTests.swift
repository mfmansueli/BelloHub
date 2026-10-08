//
//  AppLocalizationLocaleTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AppLocalization from a Locale")
struct AppLocalizationLocaleTests {
    @Test("The screens read their data files in the language the phone runs the app in",
          arguments: [
              ("pt_BR", AppLocalization.ptBR), ("pt_PT", .ptPT), ("pt_AO", .ptPT), ("es_MX", .esMX),
              ("es_ES", .es), ("es_AR", .es419), ("es-419", .es419), ("en_US", .en), ("en_GB", .enGB),
              ("en_AU", .enGB), ("fr_CA", .fr), ("de_AT", .de), ("it_IT", .it), ("tr_TR", .tr), ("id_ID", .id),
              ("hi_IN", .hi), ("ar_SA", .ar), ("ar_AE", .ar)
          ])
    func resolves(identifier: String, expected: AppLocalization) {
        #expect(AppLocalization(locale: Locale(identifier: identifier)) == expected)
    }

    @Test("A language the product does not speak reads English")
    func unknownLanguage() {
        #expect(AppLocalization(locale: Locale(identifier: "ja_JP")) == .en)
        #expect(AppLocalization(locale: Locale(identifier: "")) == .en)
    }
}
