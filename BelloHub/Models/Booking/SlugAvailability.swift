//
//  SlugAvailability.swift
//  BelloHub
//

/// What the server says about an address she may want (`isSlugAvailable`, firebase/functions/API.md section 6.2).
enum SlugAvailability: Equatable, Sendable {
    case available
    /// Someone else owns it.
    case taken
    /// A word nobody may own.
    case reserved
    /// Not a valid address at all.
    case invalid
}
