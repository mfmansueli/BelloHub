//
//  BlockTimeView.swift
//  BelloHub
//

import SwiftUI

/// 6.6 Block time, as a sheet. It reads the Services the screen needs from the environment and hands them to
/// `BlockTimeContent`, which owns the ViewModel (a View cannot read the environment in its `init`).
struct BlockTimeView: View {
    let day: Date?

    @Environment(AppointmentService.self) private var appointments
    @Environment(TimeBlockService.self) private var timeBlocks
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        BlockTimeContent(
            viewModel: BlockTimeViewModel(
                day: day, timeZoneID: settings.timeZoneID, firstWeekday: settings.firstWeekday,
                appointments: appointments, timeBlocks: timeBlocks, bookingSetup: bookingSetup, vault: vault
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
        BlockTimeView(day: nil)
    }
}
#endif
