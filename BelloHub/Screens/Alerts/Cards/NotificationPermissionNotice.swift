//
//  NotificationPermissionNotice.swift
//  BelloHub
//

import SwiftUI

/// The strip at the top of Alerts while notifications are not on: asking once (the system dialog), or pointing to
/// Settings after a refusal, since the system never asks again. It says what she gets and that no name ever appears on
/// the lock screen.
struct NotificationPermissionNotice: View {
    let notice: AlertsViewModel.PermissionNotice
    let onTurnOn: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        switch notice {
        case .none:
            EmptyView()
        case .ask:
            card(
                title: "alerts.permission.ask.title", message: "alerts.permission.ask.message",
                action: "alerts.permission.ask.action", identifier: "alerts.permission.turnOn", perform: onTurnOn
            )
        case .denied:
            card(
                title: "alerts.permission.denied.title", message: "alerts.permission.denied.message",
                action: "alerts.permission.denied.action", identifier: "alerts.permission.settings",
                perform: onOpenSettings
            )
        }
    }

    private func card(
        title: LocalizedStringKey, message: LocalizedStringKey, action: LocalizedStringKey, identifier: String,
        perform: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            InlineNotice(style: .info, title: title, message: message)
            Button(action: perform) { Text(action) }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier(identifier)
        }
    }
}
