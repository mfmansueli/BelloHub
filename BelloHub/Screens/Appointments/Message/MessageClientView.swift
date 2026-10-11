//
//  MessageClientView.swift
//  BelloHub
//

import SwiftUI

/// 3.6 MessageClient, a sheet opened with `AgendaSheet.message`. It reads the Services from the environment and hands
/// them to `MessageClientContentView`, which owns the ViewModel.
struct MessageClientView: View {
    let appointmentID: UUID
    @Environment(AppointmentService.self) private var appointments
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(BookingSetupService.self) private var setup
    @Environment(MessageService.self) private var messages
    @Environment(ClientLinkService.self) private var links

    init(appointmentID: UUID) {
        self.appointmentID = appointmentID
    }

    var body: some View {
        MessageClientContentView(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile, setup: setup,
            messages: messages, links: links
        )
    }
}

#if DEBUG
#Preview {
    AppointmentPreviewHost { world in
        MessageClientView(appointmentID: world.upcoming)
    }
}
#endif
