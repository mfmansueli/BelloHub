//
//  AccountInfo.swift
//  BelloHub
//

import Foundation

/// What `ensureAccount` answers (API.md section 6.1). The server owns every field here: the app only reads them
/// (CLAUDE.md section 2, Backend). Sensitive ones (plan, registrations) are shown by the stage that needs them (S10).
struct AccountInfo: Decodable, Equatable, Sendable {
    let uid: String
    /// Still sent by `ensureAccount`, but unused since D59: purchases carry no account token and the server does not
    /// verify them.
    let appAccountToken: String
    let registrations: Registrations
    /// The address she already owns on the server, if any.
    let slug: String?

    struct Registrations: Decodable, Equatable, Sendable {
        let count: Int
        let freeLimit: Int
    }
}
