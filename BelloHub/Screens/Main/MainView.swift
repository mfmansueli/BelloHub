//
//  MainView.swift
//  BelloHub
//

import SwiftUI

/// System `TabView` with five tabs; every tab owns its `NavigationStack`. On iOS 26 the system tab bar is the floating
/// glass bar, so nothing is drawn by hand. The signed-in user's Services are created here as `@State` once they exist
/// (clients in S4, the calendar in S6) and injected with `.environment(...)`.
struct MainView: View {
    let onSignOut: () -> Void

    @Environment(ProfileService.self) private var profile
    @Environment(NotificationService.self) private var notifications
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = MainTab.home

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: MainTab.home) {
                NavigationStack { HomeView().agendaDestinations() }
            } label: {
                Label("main.tab.home", systemImage: Icon.home.symbolName)
            }
            .accessibilityIdentifier("main.tab.home")

            Tab(value: MainTab.clients) {
                ClientsTabView()
            } label: {
                Label {
                    Text(verbatim: profile.clientTerm.titlePlural(in: locale))
                } icon: {
                    Image(icon: .clients)
                }
            }
            .accessibilityIdentifier("main.tab.clients")

            Tab(value: MainTab.calendar) {
                NavigationStack { CalendarView().agendaDestinations() }
            } label: {
                Label("main.tab.calendar", systemImage: Icon.calendar.symbolName)
            }
            .accessibilityIdentifier("main.tab.calendar")

            Tab(value: MainTab.alerts) {
                NavigationStack { AlertsView().agendaDestinations() }
            } label: {
                Label("main.tab.alerts", systemImage: Icon.bell.symbolName)
            }
            .accessibilityIdentifier("main.tab.alerts")

            Tab(value: MainTab.more) {
                MoreTab(onSignOut: onSignOut)
            } label: {
                Label("main.tab.more", systemImage: "ellipsis")
            }
            .accessibilityIdentifier("main.tab.more")
        }
        // The glass bar draws its own selection pill; only the selected item's foreground takes the selection ink.
        .tint(Palette.selectionInk)
        // The phone's pending notifications follow her calendar for as long as she is signed in and unlocked.
        .task { notifications.startListening() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await notifications.permissionMayHaveChanged() } }
        }
    }
}

#Preview {
    let vault = VaultService(repository: nil)
    MainView(onSignOut: {})
        .environment(ProfileService(vault: vault))
        .environment(vault)
        .environment(ClientRegistrationService(vault: vault))
        .environment(AppLockService(keyManager: KeyManager()))
        .environment(BookingSetupService(vault: VaultService(repository: nil)))
        .environment(PublishingService.preview)
        .environment(AppointmentService(vault: VaultService(repository: nil)))
        .environment(TimeBlockService(vault: VaultService(repository: nil)))
        .environment(MessageService(vault: VaultService(repository: nil)))
        .environment(AgendaDigestService(
            appointments: AppointmentService(vault: vault), timeBlocks: TimeBlockService(vault: vault), vault: vault
        ))
        .environment(NotificationService(
            appointments: AppointmentService(vault: vault), vault: vault, permissions: PermissionService(),
            profile: ProfileService(vault: vault)
        ))
        .environment(PermissionService())
}
