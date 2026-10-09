//
//  IntegrationsView.swift
//  BelloHub
//

import SwiftUI

/// 7.6 Integrations, as More opens it. Reads the Services from the environment and hands them to
/// `IntegrationsContentView`, which owns the ViewModel.
struct IntegrationsView: View {
    @Environment(CalendarIntegrationService.self) private var calendar
    @Environment(ProfileService.self) private var profile

    var body: some View {
        let channel = profile.profile.flatMap { try? RegionCatalog.loadBundled().preset(for: $0.regionCode) }?
            .messagingChannel
        IntegrationsContentView(calendar: calendar, messagingChannel: channel)
    }
}

#Preview {
    let vault = VaultService(repository: nil)
    NavigationStack { IntegrationsView() }
        .environment(CalendarIntegrationService())
        .environment(ProfileService(vault: vault))
        .environment(ClientRegistrationService(vault: vault))
}
