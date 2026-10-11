//
//  ImportRowIssue.swift
//  BelloHub
//

import Foundation

/// Why a row or a contact cannot become a client. It feeds `ClientImportResult.malformed` and the "can't be imported"
/// list, which says the reason in her own words so she can fix the file and try again.
enum ImportRowIssue: String, Hashable, Sendable, CaseIterable {
    /// No name at all.
    case nameMissing
    /// A name shorter than 2 or longer than 60 characters (`OnboardingRules`).
    case nameLength
    /// A phone number is there but is not a number (too short, too long, wrong length for the region).
    case invalidPhone
    /// An e-mail is there but is not an address.
    case invalidEmail

    var message: LocalizedStringResource {
        switch self {
        case .nameMissing: "import.issue.nameMissing"
        case .nameLength: "import.issue.nameLength"
        case .invalidPhone: "import.issue.invalidPhone"
        case .invalidEmail: "import.issue.invalidEmail"
        }
    }
}
