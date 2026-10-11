//
//  InterfaceLanguage.swift
//  BelloHub
//

import Foundation

/// The language the app speaks to her (routine-a item 1). It is not the business localization of her messages and
/// booking page (`ProfessionalProfile.appLocaleID`), not her region, not her time zone and not the voice language.
/// `.system` follows iOS (the iPhone language, or the per-app language set in iOS Settings); `.fixed` is her choice
/// in Language and region. Pure: how a choice turns into one localization and one locale is decided here and tested
/// for all fourteen localizations.
enum InterfaceLanguage: Equatable, Hashable, Sendable {
    case system
    case fixed(AppLocalization)

    /// What is stored in `DefaultsKey.interfaceLanguage`: `"system"` or a localization id.
    var storageValue: String {
        switch self {
        case .system: Self.systemValue
        case .fixed(let localization): localization.rawValue
        }
    }

    init(storageValue: String?) {
        if let storageValue, let localization = AppLocalization(rawValue: storageValue) {
            self = .fixed(localization)
        } else {
            self = .system
        }
    }

    static let systemValue = "system"

    /// The localization the interface is in. For `.system` it is the one iOS chose for the bundle
    /// (`Bundle.preferredLocalizations`), so the text and the formats can never disagree; a language the product does
    /// not speak falls back to English, as the bundle does.
    func localization(bundleLocalizations: [String]) -> AppLocalization {
        switch self {
        case .fixed(let localization):
            return localization
        case .system:
            for identifier in bundleLocalizations {
                if let exact = AppLocalization(rawValue: identifier) { return exact }
            }
            return AppLocalization.resolve(preferredLanguages: bundleLocalizations, regionCode: nil) ?? .en
        }
    }

    /// The locale views and formatters use. Portuguese, Spanish and English keep their variant in the region (pt-BR and
    /// pt-PT, es-MX, es-419 and es, en and en-GB), and Foundation picks the text by that region (`pt_US` reads pt-BR,
    /// `en_GB` reads en-GB), so for them the locale carries the localization's own region unless the iPhone's locale is
    /// exactly that. Other languages keep her region (`fr_AT`), or the iPhone's locale itself when it already speaks
    /// the language. Without this, Portuguese (Brazil) on an iPhone in Portugal gave `pt_PT`: every string resolved
    /// with `\.locale` came out in pt-PT while the rest was pt-BR.
    static func locale(for localization: AppLocalization, device: Locale) -> Locale {
        let deviceLanguage = device.language.languageCode?.identifier
        let deviceRegion = device.region?.identifier
        let language = localization.languageCode
        if localization.variantLivesInRegion {
            if deviceLanguage == language, deviceRegion == localization.homeRegion { return device }
            return Locale(identifier: "\(language)_\(localization.homeRegion)")
        }
        if deviceLanguage == language { return device }
        return Locale(identifier: "\(language)_\(deviceRegion ?? localization.homeRegion)")
    }

    /// The choice after looking at the per-app language iOS Settings keeps for the app (`AppleLanguages` in the app's
    /// own defaults domain). When she changed it there after choosing here, iOS Settings wins, so the two places can
    /// never disagree. `written` is what this app itself last wrote there.
    static func reconciled(
        stored: InterfaceLanguage, appDomainLanguages: [String]?, written: [String]?
    ) -> InterfaceLanguage {
        guard appDomainLanguages != written else { return stored }
        guard let first = appDomainLanguages?.first else { return .system }
        let resolved = AppLocalization(rawValue: first)
            ?? AppLocalization.resolve(preferredLanguages: [first], regionCode: nil)
        return resolved.map(InterfaceLanguage.fixed) ?? .system
    }

    /// What the app writes to `AppleLanguages`, so the next launch (and the texts iOS draws for the app: permission
    /// dialogs, the Face ID sheet, pickers) is in that language from the first frame. Nil removes the override.
    var appleLanguages: [String]? {
        switch self {
        case .system: nil
        case .fixed(let localization): [localization.rawValue]
        }
    }
}
