//
//  SessionPlanView.swift
//  BelloHub
//

import SwiftUI

/// 4.8 SessionPlan, pushed as `AgendaRoute.sessionPlan`. It reads the Services from the environment and hands them to
/// `SessionPlanContentView`, which owns the ViewModel.
struct SessionPlanView: View {
    let clientID: UUID
    @Environment(VaultService.self) private var vault
    @Environment(AppointmentService.self) private var appointments
    @Environment(ProfileService.self) private var profile

    init(clientID: UUID) {
        self.clientID = clientID
    }

    var body: some View {
        SessionPlanContentView(clientID: clientID, vault: vault, appointments: appointments, profile: profile)
    }
}

#if DEBUG
#Preview {
    AppointmentPreviewHost { world in
        NavigationStack { SessionPlanView(clientID: world.client) }
    }
}
#endif
