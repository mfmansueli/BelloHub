//
//  CancelAppointmentView.swift
//  BelloHub
//

import SwiftUI

/// 3.5 CancelAppointment, a sheet opened with `AgendaSheet.cancel`. It reads the Services from the environment and
/// hands them to `CancelAppointmentContentView`, which owns the ViewModel.
struct CancelAppointmentView: View {
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
        CancelAppointmentContentView(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile, setup: setup,
            messages: messages
        )
    }
}

#if DEBUG
#Preview {
    AppointmentPreviewHost { world in
        CancelAppointmentView(appointmentID: world.upcoming)
    }
}
#endif
