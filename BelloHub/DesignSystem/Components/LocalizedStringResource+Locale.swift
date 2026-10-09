//
//  LocalizedStringResource+Locale.swift
//  BelloHub
//

import Foundation

extension LocalizedStringResource {
    /// The same resource looked up and formatted in `locale`. Strings with arguments use a semantic key plus a
    /// default value that carries the interpolations (`LocalizedStringResource("home.greeting", defaultValue:
    /// "Good morning, \(name)")`); `Text("home.greeting \(name)")` would look up the key `home.greeting %@`,
    /// which does not exist. Pass the environment's locale so previews and the design catalog can switch language.
    func localized(in locale: Locale) -> LocalizedStringResource {
        var copy = self
        copy.locale = locale
        return copy
    }

    /// The text itself, for the components that take a `String` (`ToggleRow`, `ChoiceCard`).
    func resolved(in locale: Locale) -> String {
        String(localized: localized(in: locale))
    }
}
