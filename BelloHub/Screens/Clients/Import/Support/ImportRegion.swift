//
//  ImportRegion.swift
//  BelloHub
//

/// The region whose phone conventions read the numbers of an import: her business region, or, before the profile exists
/// (the import shortcut on the last setup screen), the one she just picked, or the phone's own as a last resort.
enum ImportRegion {
    /// Nil only when the region table is empty, which a built app never has.
    static func preset(
        code: String?, in catalog: RegionCatalog, deviceRegion: String?, languageCode: String?
    ) -> RegionPreset? {
        guard !catalog.presets.isEmpty else { return nil }
        return catalog.preset(for: code) ?? catalog.preset(deviceRegion: deviceRegion, languageCode: languageCode)
    }
}
