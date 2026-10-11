//
//  AppLocalization+Locale.swift
//  BelloHub
//

import Foundation

extension AppLocalization {
    /// The localization a screen reads its data files in (catalogs, legal texts) for a `Locale`: the app language the
    /// phone runs in, so a screen in `pt-PT` shows `pt-PT` questions. `en` when the product has no voice for it.
    init(locale: Locale) {
        let language = locale.language.languageCode?.identifier ?? "en"
        self = AppLocalization.resolve(languageCode: language, regionCode: locale.region?.identifier) ?? .en
    }
}
