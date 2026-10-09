//
//  PlanView.swift
//  BelloHub
//

import SwiftUI

/// 7.3 Plan, from More, and the paywall (D42) when `mode` is `.paywall`. Reads the subscription Service from the
/// environment and hands it to `PlanContentView`, which owns the ViewModel.
struct PlanView: View {
    let mode: PlanViewModel.Mode

    @Environment(SubscriptionService.self) private var subscription

    var body: some View {
        PlanContentView(subscription: subscription, mode: mode)
    }
}

#Preview("Plan") {
    NavigationStack { PlanView(mode: .plan) }
        .environment(SubscriptionService())
}

#Preview("Paywall") {
    NavigationStack { PlanView(mode: .paywall) }
        .environment(SubscriptionService())
}
