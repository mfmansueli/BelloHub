//
//  HomeView.swift
//  BelloHub
//

import SwiftUI

/// 2.1 Home, the first tab's root: the greeting, the next visit, the rest of today, the reminders ready to send, the
/// week in three numbers, the follow-ups due and the shortcuts. It reads the Services the screen needs from the
/// environment and hands them to `HomeContentView`, which owns the ViewModel (a View cannot read the environment in
/// its `init`, and `MainView` builds this one with a plain `init()`). The tab's stack adds `.agendaDestinations()`.
struct HomeView: View {
    @Environment(AgendaDigestService.self) private var digest
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(ProfileService.self) private var profile

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        HomeContentView(
            viewModel: HomeViewModel(settings: settings, digest: digest, bookingSetup: bookingSetup),
            settings: settings
        )
    }
}

#if DEBUG
#Preview {
    HomePreviewHost {
        NavigationStack { HomeView().agendaDestinations() }
    }
}
#endif
