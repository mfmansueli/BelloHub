//
//  VaultError.swift
//  BelloHub
//

/// Why the vault cannot encrypt or decrypt right now. User-facing wording is mapped by the caller
/// ("Unlock Bello Hub to continue"), never an SDK message.
enum VaultError: Error, Equatable {
    /// The app is locked, or the seed has not been read yet: no key is in memory.
    case locked
    /// There is no seed on this device (new phone, iCloud Keychain off): the recovery words are needed.
    case noSeed
    /// The system could not provide random bytes for a new seed.
    case entropyUnavailable
}
