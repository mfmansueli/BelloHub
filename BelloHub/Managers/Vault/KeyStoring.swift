//
//  KeyStoring.swift
//  BelloHub
//

import Foundation

/// Where the 128-bit seed lives between launches (iCloud Keychain in the app, memory in tests).
/// Nothing else reads or writes the seed.
protocol KeyStoring: Sendable {
    /// The seed, or nil when this device has none (a fresh install, or iCloud Keychain is off).
    func loadSeed() throws -> Data?
    func saveSeed(_ seed: Data) throws
    func deleteSeed() throws
}
