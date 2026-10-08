//
//  UnlockFailure.swift
//  BelloHub
//

/// Why the Locked screen could not open the app.
enum UnlockFailure: Equatable, Sendable {
    /// Face or passcode did not match.
    case notRecognized
    /// She passed the check but this phone has no key for her records (iCloud Keychain off on a new phone).
    case keyMissing
}
