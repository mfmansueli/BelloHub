//
//  AlertsView.swift
//  BelloHub
//

import SwiftUI

/// 2.4 Alerts, the fourth tab's root: booking and reschedule requests and the waitlist from the server (S8), then what
/// the phone knows by itself: the visit that starts soon and one card for everyone to reach out to (the follow-up
/// queue, routine-a item 5). It reads the Services from the environment and
/// hands them to `AlertsContentView`, which owns the ViewModel. The tab's stack adds `.agendaDestinations()`.
struct AlertsView: View {
    @Environment(AgendaDigestService.self) private var digest
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(ProfileService.self) private var profile
    @Environment(PermissionService.self) private var permissions
    @Environment(NotificationService.self) private var notifications
    @Environment(BookingSyncService.self) private var inbox
    @Environment(MailboxService.self) private var mailbox
    @Environment(FollowUpQueueService.self) private var queue

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        AlertsContentView(
            viewModel: AlertsViewModel(
                settings: settings, digest: digest, bookingSetup: bookingSetup, permissions: permissions,
                notifications: notifications, inbox: inbox, mailbox: mailbox, queue: queue
            )
        )
    }
}

#if DEBUG
#Preview {
    HomePreviewHost {
        NavigationStack { AlertsView().agendaDestinations() }
    }
}
#endif
