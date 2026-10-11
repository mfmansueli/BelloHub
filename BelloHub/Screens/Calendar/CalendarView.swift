//
//  CalendarView.swift
//  BelloHub
//

import SwiftUI

/// 2.3 Calendar, the second tab's root. It reads the Services the screen needs from the environment and hands them to
/// `CalendarContentView`, which owns the ViewModel (a View cannot read the environment in its `init`, and `MainView`
/// builds this one with a plain `init()`). The tab's stack adds `.agendaDestinations()`.
struct CalendarView: View {
    @Environment(AppointmentService.self) private var appointments
    @Environment(TimeBlockService.self) private var timeBlocks
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        CalendarContentView(
            viewModel: CalendarViewModel(
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
        NavigationStack { CalendarView().agendaDestinations() }
    }
}
#endif
