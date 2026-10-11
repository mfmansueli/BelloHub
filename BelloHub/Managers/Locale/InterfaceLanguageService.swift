//
//  InterfaceLanguageService.swift
//  BelloHub
//

import Foundation
import Observation
import SwiftUI

/// Owns the language of the interface (routine-a item 1): her choice, the localization and locale it resolves to, and
/// the three places that must hear about a change. `RootView` puts `locale` and `layoutDirection` on the whole view
/// tree (every stage, sheet, alert and the lock screen re-render at once, without losing their place);
/// `InterfaceLocale` lets ViewModels and Services build sentences in it; and the app's `AppleLanguages` makes the next
/// launch, permission dialogs and other texts iOS draws for the app start in it. Created once in `RootView`.
@MainActor
@Observable
final class InterfaceLanguageService {
    private(set) var choice: InterfaceLanguage
    private(set) var localization: AppLocalization
    private(set) var locale: Locale

    @ObservationIgnored private let defaults: UserDefaults
    /// The defaults whose `AppleLanguages` iOS reads at launch (`.standard` in the app); nil in tests and UI-test
    /// launches, which must never change how the simulator starts the next run.
    @ObservationIgnored private let systemDefaults: UserDefaults?
    /// The localizations iOS would choose for the app from its language list right now: at launch the bundle's
    /// choice, and after "Same as iPhone" removed the override, the iPhone's own list.
    @ObservationIgnored private let systemLocalizations: () -> [String]
    @ObservationIgnored private let device: Locale
    /// Where code outside the view tree reads the locale (`InterfaceLocale.set`); a recorder in tests, so a test never
    /// changes the language of the others running beside it.
    @ObservationIgnored private let mirror: @Sendable (Locale) -> Void

    /// - Parameters:
    ///   - appDomainLanguages: the per-app language iOS Settings stores for the app, read once at launch.
    init(
        defaults: UserDefaults,
        systemDefaults: UserDefaults?,
        appDomainLanguages: [String]? = nil,
        systemLocalizations: @escaping () -> [String] = InterfaceLanguageService.liveSystemLocalizations,
        device: Locale = .current,
        mirror: @escaping @Sendable (Locale) -> Void = InterfaceLocale.set
    ) {
        self.defaults = defaults
        self.systemDefaults = systemDefaults
        self.systemLocalizations = systemLocalizations
        self.device = device
        self.mirror = mirror
        var stored = InterfaceLanguage(storageValue: defaults.string(forKey: DefaultsKey.interfaceLanguage))
        if systemDefaults != nil {
            let written = defaults.stringArray(forKey: DefaultsKey.interfaceAppleLanguagesWritten)
            stored = InterfaceLanguage.reconciled(
                stored: stored, appDomainLanguages: appDomainLanguages, written: written
            )
            defaults.set(stored.storageValue, forKey: DefaultsKey.interfaceLanguage)
        }
        let resolved = stored.localization(bundleLocalizations: systemLocalizations())
        choice = stored
        localization = resolved
        locale = InterfaceLanguage.locale(for: resolved, device: device)
        mirror(locale)
    }

    // MARK: - Reading

    var layoutDirection: LayoutDirection {
        localization.isRightToLeft ? .rightToLeft : .leftToRight
    }

    // MARK: - Changing

    /// Applies a new interface language everywhere at once and remembers it.
    func choose(_ language: InterfaceLanguage) {
        guard language != choice else { return }
        choice = language
        defaults.set(language.storageValue, forKey: DefaultsKey.interfaceLanguage)
        // The override is written (or removed) first, so "Same as iPhone" resolves from the iPhone's own list.
        if let systemDefaults {
            if let languages = language.appleLanguages {
                systemDefaults.set(languages, forKey: Self.appleLanguagesKey)
                defaults.set(languages, forKey: DefaultsKey.interfaceAppleLanguagesWritten)
            } else {
                systemDefaults.removeObject(forKey: Self.appleLanguagesKey)
                defaults.removeObject(forKey: DefaultsKey.interfaceAppleLanguagesWritten)
            }
        }
        localization = language.localization(bundleLocalizations: systemLocalizations())
        locale = InterfaceLanguage.locale(for: localization, device: device)
        mirror(locale)
    }

    /// The key iOS reads for the languages of an app (the same one the per-app language of iOS Settings writes).
    nonisolated static let appleLanguagesKey = "AppleLanguages"

    /// The app's own service: her choice in the standard defaults, where iOS also reads `AppleLanguages`.
    static func live(defaults: UserDefaults) -> InterfaceLanguageService {
        InterfaceLanguageService(defaults: defaults, systemDefaults: defaults, appDomainLanguages: appDomainLanguages())
    }

    /// What iOS would pick from the app's localizations for the language list in force (the app's override, else the
    /// iPhone's), with the same algorithm the bundle uses at launch.
    nonisolated static func liveSystemLocalizations() -> [String] {
        let preferences = UserDefaults.standard.stringArray(forKey: appleLanguagesKey) ?? Locale.preferredLanguages
        return Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: preferences)
    }

    /// The per-app languages in the app's own defaults domain (not the iPhone-wide list).
    static func appDomainLanguages(bundleID: String? = Bundle.main.bundleIdentifier) -> [String]? {
        guard let bundleID else { return nil }
        return UserDefaults.standard.persistentDomain(forName: bundleID)?[appleLanguagesKey] as? [String]
    }
}
