//
//  String+Interface.swift
//  BelloHub
//

import Foundation

extension String {
    /// A catalog string in the language of the interface (`InterfaceLocale`), for code outside the view tree. Use it
    /// instead of `String(localized:)`, which always answers in the launch language
    /// (`LocalizationSourceScanTests` enforces it): `String(interface: LocalizedStringResource("key", defaultValue:
    /// "Text \(value)"))`.
    init(interface resource: LocalizedStringResource) {
        var localized = resource
        localized.locale = InterfaceLocale.current
        self.init(localized: localized)
    }
}
