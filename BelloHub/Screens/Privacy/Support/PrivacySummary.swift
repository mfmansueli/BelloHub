//
//  PrivacySummary.swift
//  BelloHub
//

import Foundation

/// The lines Privacy and security (7.7) derives: the recovery-key status ("Saved on Oct 8" / "Not saved yet"), the
/// lock-after label, and the recommended order of the lock options. Pure.
enum PrivacySummary {
    enum RecoveryLine: Equatable, Sendable {
        case notSaved
        case saved(dateText: String)
    }

    static func recoveryLine(_ status: RecoveryKeyStatus, formatters: Formatters) -> RecoveryLine {
        switch status {
        case .notSaved: .notSaved
        case .saved(let date): .saved(dateText: formatters.shortDate(date))
        }
    }

    /// The catalog key for a grace option: "Immediately", "After 30 seconds", ...
    static func graceKey(_ seconds: Int) -> String {
        switch seconds {
        case 0: "privacy.lockAfter.immediately"
        case 30: "privacy.lockAfter.30s"
        case 60: "privacy.lockAfter.1m"
        case 300: "privacy.lockAfter.5m"
        case 900: "privacy.lockAfter.15m"
        default: "privacy.lockAfter.1m"
        }
    }
}
