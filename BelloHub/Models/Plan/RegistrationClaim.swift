//
//  RegistrationClaim.swift
//  BelloHub
//

import Foundation

/// One client the phone used to ask the server to count (`reserveRegistrations`, D42): her id and, when known, her
/// phone. Since D59 nothing sends it; it stays only so an outbound queue saved by an older version still decodes.
struct RegistrationClaim: Hashable, Codable, Sendable {
    let clientID: UUID
    let phone: String?

    init(clientID: UUID, phone: String?) {
        self.clientID = clientID
        let trimmed = phone?.trimmingCharacters(in: .whitespaces)
        self.phone = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    init(_ client: Client) {
        self.init(clientID: client.id, phone: client.phoneE164)
    }
}
