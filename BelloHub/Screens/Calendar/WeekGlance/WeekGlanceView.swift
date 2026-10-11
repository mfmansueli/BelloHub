//
//  WeekGlanceView.swift
//  BelloHub
//

import SwiftUI

/// 2.6 This week: how many visits are left today, how many open slots the week has, how many clients have not been
/// back, the bookings of each working day and the first free times to offer. It reads the Services it needs from the
/// environment and hands them to `WeekGlanceContent`, which owns the ViewModel.
struct WeekGlanceView: View {
    @Environment(AppointmentService.self) private var appointments
    @Environment(TimeBlockService.self) private var timeBlocks
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        WeekGlanceContent(
            viewModel: WeekGlanceViewModel(
                timeZoneID: settings.timeZoneID, firstWeekday: settings.firstWeekday, appointments: appointments,
                timeBlocks: timeBlocks, bookingSetup: bookingSetup, vault: vault
            ),
            settings: settings
        )
        // Her zone and week start are only known once her profile is read: new ones build a new ViewModel.
        .id(settings)
    }
}

#if DEBUG
#Preview {
    CalendarPreviewHost { _ in
        NavigationStack { WeekGlanceView().agendaDestinations() }
    }
}
#endif
