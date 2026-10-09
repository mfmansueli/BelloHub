//
//  ConsentCard.swift
//  BelloHub
//

import SwiftUI

/// The consents this client signed, newest first. Each row opens the exact text that was signed.
struct ConsentCard: View {
    let consents: [Consent]
    let formatters: Formatters
    let onOpen: (Consent) -> Void

    var body: some View {
        if consents.isEmpty {
            Text("health.consent.empty")
                .font(Typography.meta)
                .foregroundStyle(Palette.ink2)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .belloCard()
                .accessibilityIdentifier("health.consent.empty")
        } else {
            ListCard(dividerInset: Spacing.md) {
                ForEach(consents) { consent in
                    ConsentRow(
                        consent: consent, formatters: formatters, identifier: "health.consent.\(consent.id.uuidString)"
                    ) {
                        onOpen(consent)
                    }
                }
            }
        }
    }
}
