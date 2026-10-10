//
//  MoreTab.swift
//  BelloHub
//

import SwiftUI

/// The More tab: its own `NavigationStack` over a typed path, and the destination of every `MoreRoute`. `MainView`
/// puts this view in the tab and knows nothing else about the screens behind it. Destinations are resolved per
/// section so each switch stays short.
struct MoreTab: View {
    let onSignOut: () -> Void

    @Environment(ProfileService.self) private var profile
    /// Optional so a preview of the shell that does not inject a vault still builds; the app always provides one.
    @Environment(VaultService.self) private var vault: VaultService?
    @State private var path: [MoreRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            MoreView()
                .navigationDestination(for: MoreRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: MoreRoute) -> some View {
        switch route.section {
        case .business: businessDestination(for: route)
        case .clients: clientsDestination(for: route)
        case .messages: QuickRepliesView()
        case .preferences: preferencesDestination(for: route)
        case .account: accountDestination(for: route)
        }
    }

    @ViewBuilder
    private func businessDestination(for route: MoreRoute) -> some View {
        switch route {
        case .products: ProductsView()
        case .bookingPage: BookingSettingsView()
        case .availability: AvailabilityView()
        case .credentials: CredentialsView()
        case .team: TeamView()
        default: ServicesView()
        }
    }

    @ViewBuilder
    private func clientsDestination(for route: MoreRoute) -> some View {
        switch route {
        case .recordTemplate: RecordTemplateView(profile: profile)
        case .formTemplates: FormTemplatesView()
        default: TagsView(profile: profile, clients: vault?.repository)
        }
    }

    @ViewBuilder
    private func preferencesDestination(for route: MoreRoute) -> some View {
        switch route {
        case .plan: PlanView(mode: .plan)
        case .notifications: NotificationSettingsView()
        case .aiSettings: AISettingsView()
        case .integrations: IntegrationsView()
        case .exportAll: ExportAllView()
        case .recoveryKey: RecoveryKeyView()
        case .help: HelpView()
        default: PrivacyView()
        }
    }

    @ViewBuilder
    private func accountDestination(for route: MoreRoute) -> some View {
        switch route {
        case .languageRegion: LanguageRegionView()
        default: AccountView(onSignOut: onSignOut)
        }
    }
}

#if DEBUG
#Preview {
    let vault = VaultService(repository: nil)
    let keys = KeyManager()
    MoreTab(onSignOut: {})
        .environment(ProfileService(vault: vault))
        .environment(vault)
        .environment(AppLockService(keyManager: keys))
        .environment(BookingSetupService(vault: vault))
        .environment(SubscriptionService.preview())
        .environment(RecoveryKeyService(keyManager: keys))
        .environment(PublishingService.preview)
}
#endif
