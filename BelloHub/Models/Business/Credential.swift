//
//  Credential.swift
//  BelloHub
//

import Foundation

/// One line of "Training and credentials": a course or certificate, or her professional registration. Whether it
/// appears on her booking page is her choice, and the screen sets it for all of them at once. The certificate photo of
/// the data model is not stored yet: photos wait for the photo pipeline (S7).
struct Credential: Identifiable, Hashable, Codable, Sendable, Positioned {
    let id: UUID
    var kind: CredentialKind
    /// "Aesthetics technical course". Empty for the registration, which is shown with its own label.
    var title: String
    /// "Senac SP". Empty when she wrote none.
    var institution: String
    var year: Int?
    /// Only for `.registration`.
    var registrationNumber: String?
    var showOnBookingPage: Bool
    var position: Int

    init(
        id: UUID = UUID(), kind: CredentialKind = .training, title: String, institution: String = "", year: Int? = nil,
        registrationNumber: String? = nil, showOnBookingPage: Bool = true, position: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.institution = institution
        self.year = year
        self.registrationNumber = registrationNumber
        self.showOnBookingPage = showOnBookingPage
        self.position = position
    }
}
