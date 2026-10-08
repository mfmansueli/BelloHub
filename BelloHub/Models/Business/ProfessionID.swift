//
//  ProfessionID.swift
//  BelloHub
//

/// The professions the product has screens and catalog entries for (docs/07-LOCALIZATION.md section 5). The raw
/// value is the key used in `Resources/Professions/*.json` and in the stored profile, so **never rename one**.
/// A profession is data, not code: adding a catalog entry for a profession listed here needs no Swift.
enum ProfessionID: String, PersistedEnum, Identifiable {
    case esthetician
    case hair
    case lash
    case nail
    case makeup
    case tattoo
    case barber
    case massage
    case other

    var id: String { rawValue }

    /// A profession a newer version added falls back to `other`, which has the generic catalog entry.
    static let fallback = ProfessionID.other
}
