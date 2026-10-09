//
//  PaywallSheet.swift
//  BelloHub
//

import SwiftUI

/// Shown when the gate says `needsSubscription` (D42): the Plan screen (7.3) opened as a sheet in its paywall form
/// (ASSUMPTION-20), with the headline that explains the limit and the reminder that existing clients, appointments
/// and records stay available. The new-client sheet and the import flow present it; it owns its navigation stack so
/// the close button and the legal links work inside the sheet.
struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PlanView(mode: .paywall)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("common.close") }
                            .accessibilityIdentifier("paywall.closeButton")
                    }
                }
        }
        .presentationBackground(Palette.bg)
    }
}

#Preview {
    PaywallSheet()
        .environment(SubscriptionService())
}
