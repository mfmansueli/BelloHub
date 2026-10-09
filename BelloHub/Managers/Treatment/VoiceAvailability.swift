//
//  VoiceAvailability.swift
//  BelloHub
//

/// Whether she can dictate a record right now. Anything but `.available` sends her to the manual form, which is
/// equally polished (docs/12-AI-AND-VOICE.md).
enum VoiceAvailability: Equatable, Sendable {
    case available
    /// The technology is not wired yet (v1 ships the front end only, D53) or the device cannot do it.
    case notAvailableYet
    case permissionDenied
    case languageUnsupported
}
