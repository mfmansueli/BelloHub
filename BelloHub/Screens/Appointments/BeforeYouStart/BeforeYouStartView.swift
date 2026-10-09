//
//  BeforeYouStartView.swift
//  BelloHub
//

import SwiftUI

/// 3.3 BeforeYouStart, a sheet opened with `AgendaSheet.beforeYouStart`. It reads the Services from the environment and
/// hands them to `BeforeYouStartContentView`, which owns the ViewModel.
struct BeforeYouStartView: View {
    let appointmentID: UUID
    @Environment(AppointmentService.self) private var appointments
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile

    init(appointmentID: UUID) {
        self.appointmentID = appointmentID
    }

    var body: some View {
        BeforeYouStartContentView(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile
        )
    }
}

#if DEBUG
#Preview {
    AppointmentPreviewHost { world in
        BeforeYouStartView(appointmentID: world.upcoming)
    }
}
#endif
