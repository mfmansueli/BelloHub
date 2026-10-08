//
//  PaywallSheet.swift
//  BelloHub
//

import SwiftUI

/// Shown when the gate says `needsSubscription` (D42). In S4 it only explains; the plan choice and the StoreKit
/// purchase replace it in S10 (the `Plan` screen opened as a sheet, ASSUMPTION-20). Existing clients, appointments and
/// records stay available and editable, and the sheet says so.
struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("paywall.title").font(Typography.title).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("paywall.title")
            Text("paywall.message").font(Typography.body).foregroundStyle(Palette.ink2)
            InlineNotice(style: .info, title: "paywall.reassurance")
            Spacer(minLength: 0)
            Button { dismiss() } label: { Text("common.close") }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("paywall.closeButton")
        }
        .padding(Spacing.gutter)
        .background(Palette.bg)
        .presentationDetents([.medium])
        .presentationBackground(Palette.bg)
    }
}

#Preview {
    PaywallSheet()
}
