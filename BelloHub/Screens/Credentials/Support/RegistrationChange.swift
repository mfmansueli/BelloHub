//
//  RegistrationChange.swift
//  BelloHub
//

import Foundation

/// What typing in the registration field means for the vault: nothing, save a registration (new or changed), or remove
/// it because she emptied the field.
enum RegistrationChange: Equatable, Sendable {
    case none
    case save(Credential)
    case remove(id: UUID)
}
