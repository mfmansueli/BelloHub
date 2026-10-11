//
//  HomeTodayCard.swift
//  BelloHub
//

import SwiftUI

/// "Today" on Home (routine-a item 4): what needs her today, each row one tap from its action. Booking requests open
/// Alerts, where they are answered; reminders and unfinished visits open the follow-up queue on their filter; the
/// notification offer asks the system only when she taps it.
struct HomeTodayCard: View {
    let pending: HomePending
    let formatters: Formatters
    let onBookingRequests: () -> Void
    let onTurnOnNotifications: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("home.today.title")
                .font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Spacing.row)
            ListCard(dividerInset: 72) {
                ForEach(pending.items) { item in row(item) }
            }
        }
        .accessibilityIdentifier("home.today")
    }

    @ViewBuilder
    private func row(_ item: HomePending.Item) -> some View {
        switch item {
        case .bookingRequests(let count):
            Button(action: onBookingRequests) {
                HomeCountRow(
                    icon: .calendar, tone: .sage, title: Text("home.today.requests"),
                    subtitle: Text("home.today.requests.subtitle"), count: formatters.number(count)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.today.requests")
        case .reminders(let count):
            NavigationLink(value: AgendaRoute.followUps(.reminders)) {
                HomeCountRow(icon: .chat, title: Text("home.today.reminders"), count: formatters.number(count))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.today.reminders")
        case .unfinishedVisits(let count):
            NavigationLink(value: AgendaRoute.followUps(.visits)) {
                HomeCountRow(
                    icon: .document, tone: .peach, title: Text("home.today.unfinished"),
                    count: formatters.number(count)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.today.unfinished")
        case .notifications:
            notificationsRow
        }
    }

    /// The system dialog is only asked from this button, once a visit is coming and the reason is clear.
    private var notificationsRow: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("onb.permissions.notifications.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("onb.permissions.notifications.text").font(Typography.meta).foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onTurnOnNotifications) { Text("onb.permissions.notifications.allow") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("home.today.notificationsButton")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("home.today.notifications")
    }
}
