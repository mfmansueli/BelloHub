//
//  LanguageRegionRules.swift
//  BelloHub
//

import Foundation

/// The rules of Language and region (7.2): what a region choice resets, what the page languages must contain, and
/// what the effective week start and clock are. One owner, so the screen only binds.
enum LanguageRegionRules {
    /// Choosing a region takes its defaults (language, currency, page languages) and drops the overrides, because
    /// a week start chosen for Brazil means nothing for Germany.
    static func choosing(_ preset: RegionPreset, in draft: LanguageRegionDraft) -> LanguageRegionDraft {
        var updated = draft
        updated.regionCode = preset.code
        updated.localization = AppLocalization(rawValue: preset.defaultLocalization) ?? draft.localization
        updated.currencyCode = preset.defaultCurrency
        updated.firstWeekday = nil
        updated.use24Hour = nil
        updated.bookingLocaleIDs = pageLocales(preset.localizations, business: updated.localization)
        return updated
    }

    /// Changing the business language keeps it on the page and keeps the other page languages.
    static func choosing(_ localization: AppLocalization, in draft: LanguageRegionDraft) -> LanguageRegionDraft {
        var updated = draft
        updated.localization = localization
        updated.bookingLocaleIDs = pageLocales(draft.bookingLocaleIDs, business: localization)
        return updated
    }

    /// Switches a page language on or off. The business language cannot be switched off.
    static func toggling(_ localization: AppLocalization, in draft: LanguageRegionDraft) -> LanguageRegionDraft {
        guard localization != draft.localization else { return draft }
        var updated = draft
        if let index = updated.bookingLocaleIDs.firstIndex(of: localization.rawValue) {
            updated.bookingLocaleIDs.remove(at: index)
        } else {
            updated.bookingLocaleIDs.append(localization.rawValue)
        }
        return updated
    }

    /// The business language first, then the others in the order given, without repeats or unknown ids.
    static func pageLocales(_ ids: [String], business: AppLocalization) -> [String] {
        var result = [business.rawValue]
        for id in ids where AppLocalization(rawValue: id) != nil && !result.contains(id) {
            result.append(id)
        }
        return result
    }

    /// The week start in force: her override or the region's.
    static func effectiveWeekConfig(_ draft: LanguageRegionDraft) -> WeekConfig {
        WeekConfig.effective(
            regionCode: draft.regionCode, languageCode: draft.localization.languageCode,
            firstWeekday: draft.firstWeekday, use24Hour: draft.use24Hour
        )
    }

    /// The currencies the menu offers: the region's own, hers, and the ones of the other presets, once each.
    static func currencyOptions(current: String, presets: [RegionPreset]) -> [String] {
        var seen: [String] = []
        for code in [current] + presets.map(\.defaultCurrency) where !seen.contains(code) {
            seen.append(code)
        }
        return seen
    }

    static let weekStartOptions = [1, 2, 7] // Sunday, Monday, Saturday

    static func hasChanges(_ draft: LanguageRegionDraft, profile: ProfessionalProfile) -> Bool {
        draft != LanguageRegionDraft(profile: profile)
    }
}
