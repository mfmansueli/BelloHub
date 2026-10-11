//
//  ClientHealthSummary.swift
//  BelloHub
//

import Foundation

/// The one line the profile shows about the health form and consents ("Signed Sep 12"). The answers themselves are
/// on the Health screen; the profile never reads them.
enum ClientHealthSummary: Equatable, Sendable {
    /// The most recent date on a health form or a consent record she marked signed (D55).
    case signed(Date)
    case notFilledIn

    static func make(forms: [HealthForm], consents: [ConsentRecord]) -> ClientHealthSummary {
        let dates = forms.compactMap(\.signedAt) + consents.filter(\.isSigned).map(\.effectiveDate)
        return dates.max().map { .signed($0) } ?? .notFilledIn
    }
}
