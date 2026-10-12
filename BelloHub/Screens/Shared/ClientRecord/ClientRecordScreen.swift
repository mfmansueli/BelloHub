//
//  ClientRecordScreen.swift
//  BelloHub
//

import SwiftUI

/// A client's record opened from outside the Clients tab (an appointment, Home, an alert), pushed on that tab's own
/// stack. It wires the record's screens with local destinations, so the tab needs no knowledge of the Clients routes:
/// editing, what she knows and health push here; the visit flow, messages and record sheets present from here.
struct ClientRecordScreen: View {
    let clientID: UUID

    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(ClientRegistrationService.self) private var registration
    @Environment(\.dismiss) private var dismiss
    @State private var clientRoute: ClientsRoute?
    @State private var recordRoute: RecordRoute?
    @State private var recordSheet: RecordSheet?
    @State private var agendaSheet: AgendaSheet?
    @State private var visitFlow: TreatmentFlowRequest?
    @State private var regions = (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: [])

    var body: some View {
        ClientProfileView(
            clientID: clientID, vault: vault, profile: profile, onOpen: { clientRoute = $0 },
            onRecord: { recordRoute = $0 }, onRecordSheet: { recordSheet = $0 },
            onVisitFlow: { visitFlow = $0 }, onAgendaSheet: { agendaSheet = $0 }
        )
        .navigationDestination(item: $clientRoute) { destination($0) }
        .recordDestination(item: $recordRoute)
        .recordSheet(item: $recordSheet)
        .agendaSheet(item: $agendaSheet)
        .treatmentFlow(item: $visitFlow)
    }

    @ViewBuilder
    private func destination(_ route: ClientsRoute) -> some View {
        switch route {
        case .profile(let id):
            ClientRecordScreen(clientID: id)
        case .edit(let id):
            ClientEditView(
                clientID: id, vault: vault, profile: profile, registrar: registration, regions: regions,
                onFinish: didFinishEditing, onOpenExisting: { _ in clientRoute = nil },
                onMerged: { clientRoute = nil }, onDeleted: { clientRoute = nil; dismiss() }
            )
        case .knowledge(let id):
            ClientKnowledgeView(clientID: id, vault: vault, registrar: registration, onFinish: { clientRoute = nil })
        case .health(let id):
            ClientHealthView(clientID: id)
        }
    }

    /// Saving goes back to the record; archiving leaves it too, since she is no longer in the lists.
    private func didFinishEditing(_ finish: ClientFormViewModel.Finish) {
        clientRoute = nil
        if case .archived = finish { dismiss() }
    }
}
