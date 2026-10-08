//
//  HealthConsentRow.swift
//  BelloHub
//

import SwiftUI

/// The profile's door to Health and consent: one line saying whether it is signed. The answers are on the next screen
/// (4.5); the profile never reads them.
struct HealthConsentRow: View {
    let summary: ClientHealthSummary
    let formatters: Formatters
    let now: Date
    let action: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        ActionRow(
            icon: .shield, title: "clientProfile.health.title", subtitle: Text(subtitle), tone: .sage,
            identifier: "clientProfile.healthRow", action: action
        )
    }

    private var subtitle: LocalizedStringResource {
        switch summary {
        case .signed(let date):
            LocalizedStringResource(
                "clientProfile.health.signed", defaultValue: "Signed \(formatters.recentDate(date, now: now))"
            ).localized(in: locale)
        case .notFilledIn:
            LocalizedStringResource("clientProfile.health.missing").localized(in: locale)
        }
    }
}
