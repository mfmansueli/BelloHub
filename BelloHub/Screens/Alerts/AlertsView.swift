//
//  AlertsView.swift
//  BelloHub
//

import SwiftUI

/// 2.4 Alerts, the fourth tab's root. Booking requests, cancellations, check-ins and forms arrive with the server (S8);
/// until then the tab shows what the phone knows by itself: the reminders ready to send (D31), the visit that starts
/// soon, birthdays, and the clients waiting in Follow-ups and Win back. It reads the Services from the environment and
/// hands them to `AlertsContentView`, which owns the ViewModel. The tab's stack adds `.agendaDestinations()`.
struct AlertsView: View {
    @Environment(AgendaDigestService.self) private var digest
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(ProfileService.self) private var profile
    @Environment(PermissionService.self) private var permissions
    @Environment(NotificationService.self) private var notifications

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        AlertsContentView(
            viewModel: AlertsViewModel(
                settings: settings, digest: digest, bookingSetup: bookingSetup, permissions: permissions,
                notifications: notifications
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
