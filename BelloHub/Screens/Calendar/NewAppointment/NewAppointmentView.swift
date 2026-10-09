//
//  NewAppointmentView.swift
//  BelloHub
//

import SwiftUI

/// 3.1 New appointment, as a sheet. It reads the Services the screen needs from the environment and hands them to
/// `NewAppointmentContent`, which owns the ViewModel (a View cannot read the environment in its `init`, and
/// `AgendaSheet` builds this one with a plain `init`).
struct NewAppointmentView: View {
    let clientID: UUID?
    let startsAt: Date?

    @Environment(AppointmentService.self) private var appointments
    @Environment(TimeBlockService.self) private var timeBlocks
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        NewAppointmentContent(
            viewModel: NewAppointmentViewModel(
                clientID: clientID, startsAt: startsAt, timeZoneID: settings.timeZoneID,
                firstWeekday: settings.firstWeekday, appointments: appointments, timeBlocks: timeBlocks,
                bookingSetup: bookingSetup, vault: vault, localization: AppLocalization(locale: locale)
            ),
            settings: settings
        )
    }
}

#if DEBUG
#Preview {
    CalendarPreviewHost { world in
        NewAppointmentView(clientID: world.clients.ana, startsAt: nil)
    }
}
#endif
