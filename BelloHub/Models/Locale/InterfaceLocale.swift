//
//  InterfaceLocale.swift
//  BelloHub
//

import Foundation
import Synchronization

/// The interface locale for code that runs outside the view tree (ViewModels, Services, rules that build a sentence).
/// Views read `\.locale`, which `RootView` sets from the same value; this mirror exists because `String(localized:)`
/// can only answer in the language the process launched with (it ignores `\.locale` and its own `locale:` argument),
/// so a sentence built in a ViewModel after she switched language would stay in the old one. `InterfaceLanguageService`
/// is the only writer.
enum InterfaceLocale {
    private static let storage = Mutex(Locale.current)

    static var current: Locale {
        storage.withLock { $0 }
    }

    /// The localization of the interface, for code that picks a per-language resource (notification texts, the
    /// profession catalog, the language the server writes pushes in).
    static var localization: AppLocalization {
        AppLocalization(resolving: current)
    }

    static func set(_ locale: Locale) {
        storage.withLock { $0 = locale }
    }
}
