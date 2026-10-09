//
//  ClientHealthView.swift
//  BelloHub
//

import SwiftUI

/// 4.5 ClientHealth: Health and consents. The entry the Clients tab pushes (`ClientsRoute.health`). It only reads the
/// Services from the environment and hands them to `ClientHealthContentView`, which owns the ViewModel: a ViewModel
/// that needs the vault cannot be made in the initializer of a view that has no parameters but the client's id.
struct ClientHealthView: View {
    let clientID: UUID
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(\.photoProcessing) private var photoProcessing
    @Environment(\.locale) private var locale

    init(clientID: UUID) {
        self.clientID = clientID
    }

    var body: some View {
        ClientHealthContentView(
            clientID: clientID, repository: vault.repository, profile: profile, photos: photoProcessing, locale: locale
        )
    }
}

#if DEBUG
#Preview {
    let repository = InMemoryClientRecordRepository()
    let client = Client(name: "Ana Costa", createdAt: Date())
    let vault = VaultService(repository: repository)
    return NavigationStack { ClientHealthView(clientID: client.id) }
        .environment(vault)
        .environment(ProfileService(vault: vault))
        .task { _ = await repository.save(client) }
}
#endif
