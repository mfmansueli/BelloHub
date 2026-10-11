//
//  AIPreferencesStoring.swift
//  BelloHub
//

import Foundation

/// Where the assistant's preferences are kept. Its own protocol so a test injects a fake and the owner can move the
/// values (for example into the vault) without touching the screen.
@MainActor
protocol AIPreferencesStoring: AnyObject {
    /// The saved preferences, or the defaults when nothing was saved or what was saved cannot be read.
    func load() -> AIPreferences
    func save(_ preferences: AIPreferences)
}
