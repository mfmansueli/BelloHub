//
//  IncidentView.swift
//  BelloHub
//

import SwiftUI

/// 4.9 Incident, presented as `RecordSheet.incident`. It reads the vault from the environment and hands it to
/// `IncidentContentView`, which owns the ViewModel.
struct IncidentView: View {
    let clientID: UUID
    let appointmentID: UUID?
    let recordID: UUID?
    @Environment(VaultService.self) private var vault
    @Environment(\.locale) private var locale

    init(clientID: UUID, appointmentID: UUID?, recordID: UUID? = nil) {
        self.clientID = clientID
        self.appointmentID = appointmentID
        self.recordID = recordID
    }

    var body: some View {
        IncidentContentView(clientID: clientID, appointmentID: appointmentID, recordID: recordID, vault: vault,
                            locale: locale)
    }
}
