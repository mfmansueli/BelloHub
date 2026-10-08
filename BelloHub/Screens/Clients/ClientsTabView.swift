//
//  ClientsTabView.swift
//  BelloHub
//

import SwiftUI

/// The Clients tab: its own `NavigationStack` over a typed route (`ClientsRoute`), the new-client and import sheets
/// and the wiring between the screens. The Services it needs are read from the environment here, once, and handed
/// to the screens, which build their own ViewModels from them (CLAUDE.md section 2: screens never create Services).
struct ClientsTabView: View {
    private enum Sheet: String, Identifiable {
        case newClient
        case importClients

        var id: String { rawValue }
    }

    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(ClientRegistrationService.self) private var registration
    @State private var path: [ClientsRoute] = []
    @State private var sheet: Sheet?
    // Why here: the phone normalizer needs the region table, and this is the one place that reads it for the tab.
    @State private var regions = (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: [])

    var body: some View {
        NavigationStack(path: $path) {
            ClientsView(
                vault: vault, profile: profile, onAdd: { sheet = .newClient }, onImport: { sheet = .importClients }
            )
            .navigationDestination(for: ClientsRoute.self) { destination($0) }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .newClient: newClient
            case .importClients: ImportClientsView(onViewClients: { self.sheet = nil })
            }
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(_ route: ClientsRoute) -> some View {
        switch route {
        case .profile(let clientID):
            ClientProfileView(clientID: clientID, vault: vault, profile: profile, onOpen: { path.append($0) })
        case .edit(let clientID):
            ClientEditView(
                clientID: clientID, vault: vault, profile: profile, registrar: registration, regions: regions,
                onFinish: didFinishEditing, onOpenExisting: { path.append(.profile(clientID: $0)) },
                onMerged: { path.removeLast() }
            )
        case .knowledge(let clientID):
            ClientKnowledgeView(
                clientID: clientID, vault: vault, registrar: registration, onFinish: { path.removeLast() }
            )
        case .health(let clientID):
            ClientHealthView(clientID: clientID)
        }
    }

    private var newClient: some View {
        NewClientView(
            vault: vault, profile: profile, registrar: registration, regions: regions,
            onFinish: didFinishAdding,
            onOpenExisting: { existingID in
                sheet = nil
                path.append(.profile(clientID: existingID))
            },
            onViewClients: { sheet = nil }
        )
    }

    // MARK: - Where each ending goes

    /// A new client opens her profile; anything else the sheet ended with just closes it.
    private func didFinishAdding(_ finish: ClientFormViewModel.Finish) {
        sheet = nil
        if case .registered(let clientID) = finish { path.append(.profile(clientID: clientID)) }
    }

    /// Saving or restoring goes back to the profile; archiving leaves the profile of someone now out of the lists,
    /// so it goes back to the list.
    private func didFinishEditing(_ finish: ClientFormViewModel.Finish) {
        switch finish {
        case .archived: path.removeAll()
        case .registered, .updated, .restored: if !path.isEmpty { path.removeLast() }
        }
    }
}
