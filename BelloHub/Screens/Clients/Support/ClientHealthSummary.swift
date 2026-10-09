//
//  ClientHealthSummary.swift
//  BelloHub
//

import Foundation

/// The one line the profile shows about the health form and consent ("Signed Sep 12"). The answers themselves are on
/// the Health and consent screen; the profile never reads them.
enum ClientHealthSummary: Equatable, Sendable {
    /// The most recent signature on a health form or a consent.
    case signed(Date)
    case notFilledIn

    static func make(forms: [HealthForm], consents: [Consent]) -> ClientHealthSummary {
        let dates = forms.compactMap(\.signedAt) + consents.map(\.signedAt)
        return dates.max().map { .signed($0) } ?? .notFilledIn
    }
}
