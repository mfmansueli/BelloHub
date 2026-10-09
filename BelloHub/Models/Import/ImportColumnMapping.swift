//
//  ImportColumnMapping.swift
//  BelloHub
//

import Foundation

/// What a column of the file holds, as far as a client needs: a name (a full name, or a first name when a last-name
/// column is mapped too), the last name, a phone number and an e-mail.
enum ImportColumnRole: String, CaseIterable, Hashable, Sendable {
    case name
    case lastName
    case phone
    case email
}

/// Which column of the file feeds each part of a client. Nil means "not in the file". She can change every choice in
/// the mapping step; `ImportColumnMapper.detect` makes the first guess.
struct ImportColumnMapping: Equatable, Sendable {
    var name: Int?
    var lastName: Int?
    var phone: Int?
    var email: Int?

    subscript(role: ImportColumnRole) -> Int? {
        get {
            switch role {
            case .name: name
            case .lastName: lastName
            case .phone: phone
            case .email: email
            }
        }
        set {
            switch role {
            case .name: name = newValue
            case .lastName: lastName = newValue
            case .phone: phone = newValue
            case .email: email = newValue
            }
        }
    }

    /// A row needs a name to become a client, so the mapping needs a name column.
    var hasName: Bool { name != nil }
}
