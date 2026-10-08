//
//  RegionCatalog.swift
//  BelloHub
//

import Foundation

/// Answers questions about the region presets. Pure: it holds an array, so tests build their own
/// (`RegionCatalog+Bundle.swift` in `Managers/Locale/` loads the shipped `regions.json`).
struct RegionCatalog: Sendable {
    let presets: [RegionPreset]

    func preset(for code: String?) -> RegionPreset? {
        guard let code = code?.uppercased() else { return nil }
        return presets.first { $0.code == code }
    }

    /// The preset whose calling code is the longest prefix of `digits`. The United States wins "1"
    /// over any longer code that does not exist here.
    func preset(matchingInternationalDigits digits: String) -> RegionPreset? {
        presets
            .filter { digits.hasPrefix($0.callingCode) }
            .max { $0.callingCode.count < $1.callingCode.count }
    }

    /// The preset to use for a device region. A region that is not in the table gets the closest
    /// preset by language (the Netherlands gets the United Kingdom's English preset); the
    /// professional then picks region and currency by hand. Never fails, so sign-up is never blocked.
    func preset(deviceRegion: String?, languageCode: String?) -> RegionPreset {
        if let exact = preset(for: deviceRegion) { return exact }
        // A language the product does not speak (Dutch) reads English, and most of the world writes
        // British English, hence `en-GB`: the Netherlands gets the United Kingdom's preset.
        let resolved = AppLocalization.resolve(languageCode: languageCode ?? "en", regionCode: deviceRegion)
        let localization = resolved ?? .enGB
        let byLanguage = presets
            .filter { $0.defaultLocalization == localization.rawValue }
            .min { $0.wave < $1.wave }
        return byLanguage ?? preset(for: "GB") ?? presets[0]
    }

    func presets(inWave wave: Int) -> [RegionPreset] {
        presets.filter { $0.wave == wave }
    }

    /// Presets in the order the country picker shows them: the preset countries first, by wave, then by code.
    var presetsForPicker: [RegionPreset] {
        presets.sorted { ($0.wave, $0.code) < ($1.wave, $1.code) }
    }

    /// Currency Foundation knows for any ISO region, for regions without a preset.
    static func currencyCode(forRegion code: String) -> String? {
        Locale(identifier: "und_\(code)").currency?.identifier
    }
}
