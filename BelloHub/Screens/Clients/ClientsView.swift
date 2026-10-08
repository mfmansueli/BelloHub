//
//  ClientsView.swift
//  BelloHub
//

import SwiftUI

/// 2.2 Clients. The list arrives in S4; until then the tab shows an honest empty state. The title follows what she
/// calls the people she serves.
struct ClientsView: View {
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale

    var body: some View {
        EmptyState(icon: .clients, title: "clients.empty.title", message: "clients.empty.message")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.bg)
            .navigationTitle(Text(verbatim: profile.clientTerm.titlePlural(in: locale)))
            .accessibilityIdentifier("clients.empty")
    }
}

#Preview {
    NavigationStack { ClientsView() }
        .environment(ProfileService(vault: VaultService(repository: nil)))
}
