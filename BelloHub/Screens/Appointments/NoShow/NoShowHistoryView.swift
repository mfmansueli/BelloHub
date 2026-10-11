//
//  NoShowHistoryView.swift
//  BelloHub
//

import SwiftUI

/// 4.11 NoShowHistory, pushed as `AgendaRoute.noShowHistory`. It reads the Services from the environment and hands
/// them to `NoShowHistoryContentView`, which owns the ViewModel.
struct NoShowHistoryView: View {
    let clientID: UUID
    @Environment(VaultService.self) private var vault
    @Environment(AppointmentService.self) private var appointments
    @Environment(ProfileService.self) private var profile
    @Environment(BookingSetupService.self) private var setup

    init(clientID: UUID) {
        self.clientID = clientID
    }

    var body: some View {
        NoShowHistoryContentView(
            clientID: clientID, vault: vault, appointments: appointments, profile: profile, setup: setup
        )
    }
}

#if DEBUG
#Preview {
    AppointmentPreviewHost { world in
        NavigationStack { NoShowHistoryView(clientID: world.client) }
    }
}
#endif
