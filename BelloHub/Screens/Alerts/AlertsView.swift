//
//  AlertsView.swift
//  BelloHub
//

import SwiftUI

/// 2.4 Alerts. Booking requests and reminders arrive with the server (S8); until then the tab shows an honest empty
/// state.
struct AlertsView: View {
    var body: some View {
        EmptyState(icon: .bell, title: "alerts.empty.title", message: "alerts.empty.message")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.bg)
            .navigationTitle(Text("main.tab.alerts"))
            .accessibilityIdentifier("alerts.empty")
    }
}

#Preview {
    NavigationStack { AlertsView() }
}
