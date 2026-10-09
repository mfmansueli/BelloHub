//
//  RunningLateView.swift
//  BelloHub
//

import SwiftUI

/// 2.12 RunningLate, a sheet opened with `AgendaSheet.runningLate`. It reads the Services from the environment and
/// hands them to `RunningLateContentView`, which owns the ViewModel.
struct RunningLateView: View {
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
        RunningLateContentView(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile, setup: setup,
            messages: messages
        )
    }
}

#if DEBUG
#Preview {
    AppointmentPreviewHost { world in
        RunningLateView(appointmentID: world.upcoming)
    }
}
#endif
