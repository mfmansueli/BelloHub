//
//  SuggestedService.swift
//  BelloHub
//

/// A service the catalog suggests for a profession. Keys are unique across the whole catalog (`esthetician.glow`),
/// so choosing two professions never lists the same service twice under different keys.
struct SuggestedService: Identifiable, Hashable, Codable, Sendable {
    let key: String
    let name: String
    let category: String
    let minutes: Int
    /// Weeks until a client is due for a follow-up. Nil for services that are one-off.
    let followUpWeeks: Int?
    /// Preselected in the onboarding list.
    let selected: Bool
    /// Whether the service reminds the professional to take before and after photos.
    let photos: Bool

    var id: String { key }
}
