//
//  AccountRules.swift
//  BelloHub
//

import Foundation

/// What the account form accepts (7.1). The same cleaning the setup applies to names, so a profile edited here reads
/// like one created there.
enum AccountRules {
    static let maxNameLength = 60

    enum NameIssue: Equatable, Sendable {
        case empty
        case tooLong
    }

    static func cleaned(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNameLength * 2))
    }

    static func nameIssue(_ text: String) -> NameIssue? {
        let name = cleaned(text)
        if name.isEmpty { return .empty }
        if name.count > maxNameLength { return .tooLong }
        return nil
    }

    /// The business name is optional; when given it has the same limit.
    static func businessNameIssue(_ text: String) -> NameIssue? {
        let name = cleaned(text)
        return name.count > maxNameLength ? .tooLong : nil
    }

    /// Whether the form holds something different from the stored profile.
    static func hasChanges(displayName: String, businessName: String, profile: ProfessionalProfile?) -> Bool {
        guard let profile else { return false }
        return cleaned(displayName) != profile.displayName || cleaned(businessName) != profile.businessName
    }
}
