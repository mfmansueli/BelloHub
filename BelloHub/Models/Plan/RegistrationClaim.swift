//
//  RegistrationClaim.swift
//  BelloHub
//

import Foundation

/// One client the phone asks the server to count (`reserveRegistrations`, D42): her id and, when known, her phone, so
/// the same person booked through the link and typed in the app never counts twice.
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
