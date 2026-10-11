//
//  HomeView.swift
//  BelloHub
//

import SwiftUI

/// 2.1 Home, the first tab's root (routine-a item 4): the greeting, "New appointment" in the navigation bar, the next
/// visit, today's pending items, the rest of today, one card for everyone to reach out to and the week. It reads the
/// Services the screen needs from the environment and hands them to `HomeContentView`, which owns the ViewModel (a
/// View cannot read the environment in its `init`). The tab's stack adds `.agendaDestinations()`.
struct HomeView: View {
    @Environment(AgendaDigestService.self) private var digest
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(ProfileService.self) private var profile
    @Environment(FollowUpQueueService.self) private var queue
    @Environment(BookingSyncService.self) private var inbox: BookingSyncService?
    @Environment(PermissionService.self) private var permissions: PermissionService?
    @Environment(NotificationService.self) private var notifications: NotificationService?

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        HomeContentView(
            viewModel: HomeViewModel(
                settings: settings, digest: digest, bookingSetup: bookingSetup, queue: queue, inbox: inbox,
                permissions: permissions, notifications: notifications
            ),
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
