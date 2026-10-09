//
//  NotificationSettingsContentView.swift
//  BelloHub
//

import SwiftUI

/// What reaches her (bookings, cancellations, check-ins, follow-ups, birthdays), quiet hours with the urgent
/// exceptions, the daily summary, and what reaches her clients (reminders and their time). The system permission is
/// explained honestly at the top: ask once, then Settings.
struct NotificationSettingsContentView: View {
    @State private var viewModel: NotificationSettingsViewModel

    init(service: NotificationSettingsService) {
        _viewModel = State(initialValue: NotificationSettingsViewModel(service: service))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("notificationSettings.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                permissionNotice
                if let message = viewModel.errorMessage {
                    ErrorNotice(message: message).accessibilityIdentifier("notificationSettings.error")
                }
                forYou
                quietHours
                forClients
                privacyLink
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("notificationSettings.title"))
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.refresh() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var permissionNotice: some View {
        switch viewModel.permission {
        case .ask:
            VStack(alignment: .leading, spacing: Spacing.row) {
                InlineNotice(
                    style: .info, title: "notificationSettings.permission.ask.title",
                    message: "notificationSettings.permission.ask.message"
                )
                Button(action: viewModel.askPermission) { Text("notificationSettings.permission.allow") }
                    .buttonStyle(.belloPrimary)
                    .disabled(viewModel.isAsking)
                    .accessibilityIdentifier("notificationSettings.allowButton")
            }
        case .denied:
            VStack(alignment: .leading, spacing: Spacing.row) {
                InlineNotice(
                    style: .warning, title: "notificationSettings.permission.denied.title",
                    message: "notificationSettings.permission.denied.message"
                )
                .accessibilityIdentifier("notificationSettings.deniedNotice")
                Button(action: viewModel.openSettings) { Text("notificationSettings.permission.openSettings") }
                    .buttonStyle(.belloSecondary)
                    .accessibilityIdentifier("notificationSettings.openSettingsButton")
            }
        case .granted:
            EmptyView()
        }
    }

    private var forYou: some View {
        SettingsSection(title: "notificationSettings.section.forYou") {
            ListCard(dividerInset: Spacing.md) {
                toggle("notificationSettings.newBookings", "notificationSettings.newBookings.subtitle",
                       \.newBookings, "notificationSettings.newBookingsSwitch")
                toggle("notificationSettings.cancellations", "notificationSettings.cancellations.subtitle",
                       \.cancellations, "notificationSettings.cancellationsSwitch")
                toggle("notificationSettings.checkIns", "notificationSettings.checkIns.subtitle",
                       \.clientCheckIns, "notificationSettings.checkInsSwitch")
                toggle("notificationSettings.followUps", "notificationSettings.followUps.subtitle",
                       \.followUpsDue, "notificationSettings.followUpsSwitch")
                toggle("notificationSettings.birthdays", "notificationSettings.birthdays.subtitle",
                       \.birthdays, "notificationSettings.birthdaysSwitch")
                toggle("notificationSettings.dailySummary", "notificationSettings.dailySummary.subtitle",
                       \.dailySummary, "notificationSettings.dailySummarySwitch")
            }
        }
    }

    private var quietHours: some View {
        SettingsSection(title: "notificationSettings.section.quietHours") {
            ListCard(dividerInset: Spacing.md) {
                ToggleRow(
                    title: String(localized: "notificationSettings.quietHours"),
                    subtitle: String(localized: "notificationSettings.quietHours.subtitle"),
                    isOn: Binding(get: { viewModel.quietHoursOn }, set: { viewModel.setQuietHours(on: $0) }),
                    identifier: "notificationSettings.quietHoursSwitch"
                )
                if viewModel.quietHoursOn {
                    timeRow("notificationSettings.quietHours.from", date: viewModel.quietFrom,
                            identifier: "notificationSettings.quietFromPicker", onChange: viewModel.setQuietFrom)
                    timeRow("notificationSettings.quietHours.until", date: viewModel.quietUntil,
                            identifier: "notificationSettings.quietUntilPicker", onChange: viewModel.setQuietUntil)
                    Text("notificationSettings.quietHours.urgent")
                        .font(Typography.footnote).foregroundStyle(Palette.ink2)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                }
            }
        }
    }

    private var forClients: some View {
        SettingsSection(title: "notificationSettings.section.forClients") {
            ListCard(dividerInset: Spacing.md) {
                toggle("notificationSettings.reminders", "notificationSettings.reminders.subtitle",
                       \.clientRemindersEnabled, "notificationSettings.remindersSwitch")
                if viewModel.prefs.clientRemindersEnabled {
                    timeRow("notificationSettings.reminders.time", date: viewModel.reminderTime,
                            identifier: "notificationSettings.reminderTimePicker", onChange: viewModel.setReminderTime)
                }
            }
        }
    }

    private var privacyLink: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("notificationSettings.privacy.note").font(Typography.footnote).foregroundStyle(Palette.ink2)
            NavigationLink(value: MoreRoute.privacy) { Text("notificationSettings.privacy.open") }
                .buttonStyle(.belloTertiary)
                .accessibilityIdentifier("notificationSettings.openPrivacyButton")
        }
    }

    // MARK: - Parts

    private func toggle(
        _ title: LocalizedStringResource, _ subtitle: LocalizedStringResource,
        _ keyPath: WritableKeyPath<NotificationPrefs, Bool>, _ identifier: String
    ) -> some View {
        ToggleRow(
            title: String(localized: title), subtitle: String(localized: subtitle),
            isOn: Binding(
                get: { viewModel.prefs[keyPath: keyPath] },
                set: { value in viewModel.update { $0[keyPath: keyPath] = value } }
            ),
            identifier: identifier
        )
    }

    private func timeRow(
        _ title: LocalizedStringKey, date: Date, identifier: String, onChange: @escaping @MainActor (Date) -> Void
    ) -> some View {
        DatePicker(selection: Binding(get: { date }, set: { onChange($0) }), displayedComponents: .hourAndMinute) {
            Text(title).font(Typography.body).foregroundStyle(Palette.ink)
        }
        .tint(Palette.roseText)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .accessibilityIdentifier(identifier)
    }
}
