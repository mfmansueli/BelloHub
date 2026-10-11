//
//  IntegrationsContentView.swift
//  BelloHub
//

import SwiftUI

/// Connected apps (Google Calendar coming soon, Apple Calendar with the access flow), WhatsApp, the Instagram bio
/// link (her booking link) and the import of contacts (the import sheet of 4.6).
struct IntegrationsContentView: View {
    @State private var viewModel: IntegrationsViewModel

    @Environment(ProfileService.self) private var profile

    init(calendar: CalendarIntegrationService, messagingChannel: MessagingChannel?) {
        _viewModel = State(initialValue: IntegrationsViewModel(calendar: calendar, messagingChannel: messagingChannel))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("integrations.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                calendars
                messaging
                clients
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("integrations.title"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: viewModel.refresh)
        .sheet(isPresented: Binding(get: { viewModel.showsImport }, set: viewModel.presentImport)) {
            ImportClientsView(
                businessRegionCode: profile.profile?.regionCode, clientTerm: profile.clientTerm,
                onViewClients: { viewModel.presentImport(false) }
            )
        }
    }

    // MARK: - Sections

    private var calendars: some View {
        SettingsSection(title: "integrations.section.calendars") {
            ListCard(dividerInset: 72) {
                // Google Calendar needs OAuth credentials a human provides (H9): shown, not offered.
                MoreRow(
                    icon: .calendar, tint: .neutral, title: Text("integrations.google"),
                    subtitle: Text("integrations.comingSoon")
                )
                .accessibilityIdentifier("integrations.googleRow")
                appleCalendarRow
            }
        }
    }

    @ViewBuilder
    private var appleCalendarRow: some View {
        switch viewModel.summary.appleCalendar {
        case .deniedInSettings:
            Button(action: viewModel.openSettings) {
                MoreRow(
                    icon: .calendar, tint: .sage, title: Text("integrations.apple"),
                    subtitle: Text("integrations.apple.denied"), showsChevron: true
                )
            }
            .accessibilityIdentifier("integrations.appleSettingsButton")
        default:
            HStack(spacing: Spacing.row) {
                MoreRow(
                    icon: .calendar, tint: .sage, title: Text("integrations.apple"),
                    subtitle: Text(viewModel.appleCalendarOn ? "integrations.apple.on" : "integrations.apple.subtitle")
                )
                Toggle(isOn: Binding(get: { viewModel.appleCalendarOn }, set: { viewModel.setAppleCalendar(on: $0) })) {
                    Text("integrations.apple")
                }
                .labelsHidden()
                .tint(Palette.sage)
                .disabled(viewModel.isConnecting)
                .padding(.trailing, Spacing.md)
                .accessibilityIdentifier("integrations.appleSwitch")
            }
        }
    }

    private var messaging: some View {
        SettingsSection(title: "integrations.section.messaging") {
            ListCard(dividerInset: 72) {
                MoreRow(
                    icon: .chat, tint: .sage, title: Text("integrations.whatsapp"),
                    subtitle: Text(viewModel.summary.whatsApp == .connected
                                   ? "integrations.whatsapp.subtitle" : "integrations.whatsapp.messages")
                )
                .accessibilityIdentifier("integrations.whatsappRow")
                NavigationLink(value: MoreRoute.bookingPage) {
                    MoreRow(
                        icon: .link, tint: .rose, title: Text("integrations.instagram"),
                        subtitle: Text("integrations.instagram.subtitle"), showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("integrations.instagramRow")
            }
        }
    }

    private var clients: some View {
        SettingsSection(title: "integrations.section.clients") {
            ListCard(dividerInset: 72) {
                Button { viewModel.presentImport(true) } label: {
                    MoreRow(
                        icon: .userPlus, tint: .peach, title: Text("integrations.import"),
                        subtitle: Text("integrations.import.subtitle"), showsChevron: true
                    )
                }
                .accessibilityIdentifier("integrations.importButton")
            }
        }
    }
}
