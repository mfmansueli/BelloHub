//
//  AppointmentView.swift
//  BelloHub
//

import SwiftUI

/// 3.2 Appointment, pushed as `AgendaRoute.appointment`. It reads the Services from the environment and hands them to
/// `AppointmentContentView`, which owns the ViewModel: a ViewModel that needs the Services cannot be made in the
/// initializer of a view whose only parameter is the visit's id.
struct AppointmentView: View {
    let appointmentID: UUID
    @Environment(AppointmentService.self) private var appointments
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(BookingSetupService.self) private var setup

    init(appointmentID: UUID) {
        self.appointmentID = appointmentID
    }

    var body: some View {
        AppointmentContentView(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile, setup: setup
        )
    }
}

#if DEBUG
#Preview {
    AppointmentPreviewHost { world in
        NavigationStack { AppointmentView(appointmentID: world.upcoming).agendaDestinations() }
    }
}
#endif
