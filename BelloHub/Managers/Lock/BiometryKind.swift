//
//  BiometryKind.swift
//  BelloHub
//

/// What the phone can unlock with, for the label and the icon of the Locked screen.
enum BiometryKind: Equatable, Sendable {
    case faceID
    case touchID
    case opticID
    /// No biometrics enrolled: only the device passcode.
    case passcodeOnly
}
