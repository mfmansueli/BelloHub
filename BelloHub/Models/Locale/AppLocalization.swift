//
//  AppLocalization.swift
//  BelloHub
//

import Foundation

/// The fourteen localizations of the product (docs/07-LOCALIZATION.md section 1). `es419` and `enGB`
/// are derived from `esMX` and `en` by `scripts/derive-locales.py`.
enum AppLocalization: String, CaseIterable, Identifiable, Hashable, Sendable {
    case ptBR = "pt-BR"
    case ptPT = "pt-PT"
    case esMX = "es-MX"
    case es419 = "es-419"
    case es
    case en
    case enGB = "en-GB"
    case it
    case fr
    case de
    case tr
    case id
    case hi
    case ar

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    /// ISO 639 language code without the region.
    var languageCode: String {
        String(rawValue.prefix { $0 != "-" })
    }

    var isRightToLeft: Bool { self == .ar }

    /// The region the localization speaks for when nothing else says (the interface locale of a choice made in the
    /// app, `InterfaceLanguage.locale`). Resolving the language with this region always gives the localization back.
    var homeRegion: String {
        switch self {
        case .ptBR: "BR"
        case .ptPT: "PT"
        case .esMX: "MX"
        case .es419: "419"
        case .es: "ES"
        case .en: "US"
        case .enGB: "GB"
        case .it: "IT"
        case .fr: "FR"
        case .de: "DE"
        case .tr: "TR"
        case .id: "ID"
        case .hi: "IN"
        case .ar: "SA"
        }
    }

    /// The localization a locale speaks (the interface locale back to its localization), English for a language the
    /// product does not have.
    init(resolving locale: Locale) {
        let language = locale.language.languageCode?.identifier ?? "en"
        self = Self.resolve(languageCode: language, regionCode: locale.region?.identifier) ?? .en
    }

    /// The language each person reads it in, written in itself (for language pickers).
    var nativeName: String {
        switch self {
        case .ptBR: "Português (Brasil)"
        case .ptPT: "Português (Portugal)"
        case .esMX: "Español (México)"
        case .es419: "Español (Latinoamérica)"
        case .es: "Español (España)"
        case .en: "English (US)"
        case .enGB: "English (UK)"
        case .it: "Italiano"
        case .fr: "Français"
        case .de: "Deutsch"
        case .tr: "Türkçe"
        case .id: "Bahasa Indonesia"
        case .hi: "हिन्दी"
        case .ar: "العربية"
        }
    }

    /// The localization a professional gets by default from the device language and region. Pure and
    /// table-tested; iOS itself picks the UI language from the app's `.lproj` folders, this decides the
    /// *business* localization (messages, booking page, templates).
    /// Returns nil for a language the product does not speak, so the caller can fall back to `en`.
    static func resolve(languageCode: String, regionCode: String?) -> AppLocalization? {
        let language = languageCode.lowercased()
        let region = regionCode?.uppercased()
        switch language {
        case "pt":
            // Portuguese without a region, or from Brazil, is the Brazilian voice (the reference voice).
            return region == nil || region == "BR" ? .ptBR : .ptPT
        case "es": return resolveSpanish(region: region)
        case "en": return resolveEnglish(region: region)
        default: return singleVoiceLanguages[language]
        }
    }

    /// Languages with one localization, whatever the region (Belgium, Canada and Switzerland French fall to
    /// `fr`; Austria and Switzerland German to `de`; every Arabic-speaking region to `ar`).
    private static let singleVoiceLanguages: [String: AppLocalization] = [
        "it": .it, "fr": .fr, "de": .de, "tr": .tr, "id": .id, "hi": .hi, "ar": .ar
    ]

    private static let latinAmericanRegions: Set<String> = [
        "AR", "BO", "CL", "CO", "CR", "CU", "DO", "EC", "GT", "HN", "NI", "PA", "PE", "PR", "PY", "SV", "UY", "VE",
        "419"
    ]
    /// English-speaking regions that follow British spelling. The United States, Canada and the
    /// Philippines keep American spelling.
    private static let britishEnglishRegions: Set<String> = [
        "GB", "IE", "AU", "NZ", "ZA", "IN", "SG", "MY", "HK", "NG", "KE", "PK", "AE", "SA"
    ]

    private static func resolveSpanish(region: String?) -> AppLocalization {
        guard let region else { return .es }
        if region == "ES" { return .es }
        // Spanish speakers in the United States are served by the Mexican voice.
        if region == "MX" || region == "US" { return .esMX }
        return latinAmericanRegions.contains(region) ? .es419 : .es
    }

    private static func resolveEnglish(region: String?) -> AppLocalization {
        guard let region else { return .en }
        return britishEnglishRegions.contains(region) ? .enGB : .en
    }

    /// First supported localization among the user's preferred languages (BCP 47 identifiers such as
    /// "pt-BR" or "es-AR"), using `regionCode` when an identifier carries none.
    static func resolve(preferredLanguages: [String], regionCode: String?) -> AppLocalization? {
        for identifier in preferredLanguages {
            let language = Locale.Language(identifier: identifier)
            guard let code = language.languageCode?.identifier else { continue }
            let region = language.region?.identifier ?? regionCode
            if let found = resolve(languageCode: code, regionCode: region) { return found }
        }
        return nil
    }
}
