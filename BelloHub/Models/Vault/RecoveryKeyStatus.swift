//
//  RecoveryKeyStatus.swift
//  BelloHub
//

import Foundation

/// Whether she told the app she put her 12 words somewhere safe, and when. A local, non-secret setting
/// (docs/06-PRIVACY-SECURITY.md section 4.2) read by Privacy and security for its "Saved on Oct 8" line.
enum RecoveryKeyStatus: Equatable, Sendable {
    case notSaved
    case saved(on: Date)

    var isSaved: Bool {
        if case .saved = self { return true }
        return false
    }

    var savedAt: Date? {
        if case .saved(let date) = self { return date }
        return nil
    }
}
