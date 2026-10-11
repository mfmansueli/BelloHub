//
//  NoShowMarkView.swift
//  BelloHub
//

import SwiftUI

/// 3.7 NoShowMark, a sheet opened with `AgendaSheet.noShowMark`. It reads the Services from the environment and hands
/// them to `NoShowMarkContentView`, which owns the ViewModel.
struct NoShowMarkView: View {
    let appointmentID: UUID
    @Environment(AppointmentService.self) private var appointments
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(BookingSetupService.self) private var setup
    @Environment(MessageService.self) private var messages

    init(appointmentID: UUID) {
        self.appointmentID = appointmentID
    }

    var body: some View {
        NoShowMarkContentView(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile, setup: setup,
            messages: messages
        )
    }
}

#if DEBUG
#Preview {
    AppointmentPreviewHost { world in
        NoShowMarkView(appointmentID: world.missed)
    }
}
#endif
