//
//  RegistrationLimitNote.swift
//  BelloHub
//

import SwiftUI

/// The sentence every screen that can create clients shows before she does (D42): the first 10 registrations are free
/// and deleted clients still count, with an "x of 10 used" counter. Hidden with a plan, where there is no limit.
struct RegistrationLimitNote: View {
    let usage: RegistrationUsage
    @Environment(\.locale) private var locale

    var body: some View {
        if !usage.isUnlimited {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("registration.limit.explainer").font(Typography.footnote).foregroundStyle(Palette.ink2)
                Text(LocalizedStringResource(
                    "registration.limit.counter",
                    defaultValue: "\(usage.used) of \(usage.limit) free registrations used"
                ).localized(in: locale))
                    .font(Typography.footnoteStrong).foregroundStyle(Palette.ink)
                    .motionNumber(usage.used)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("registration.limitNote")
        }
    }
}

#Preview {
    RegistrationLimitNote(usage: RegistrationUsage(quota: RegistrationQuota(ledgerCount: 4, hasActivePlan: false)))
        .padding()
}
