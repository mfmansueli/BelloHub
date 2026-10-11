//
//  FollowUpsView.swift
//  BelloHub
//

import SwiftUI

/// 2.7 The follow-up queue (routine-a item 5), pushed from Home, Alerts, Week at a glance and Clients
/// (`AgendaRoute.followUps(filter)` and `.winBack`). It reads the Services from the environment and hands them to
/// `FollowUpsContentView`, which owns the ViewModel.
struct FollowUpsView: View {
    var filter: FollowUpFilter = .all

    @Environment(AgendaDigestService.self) private var digest
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(ProfileService.self) private var profile
    @Environment(FollowUpQueueService.self) private var queue
    @Environment(AppointmentService.self) private var appointments
    @Environment(BookingSyncService.self) private var inbox: BookingSyncService?

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        FollowUpsContentView(
            viewModel: FollowUpsViewModel(
                settings: settings, digest: digest, bookingSetup: bookingSetup, queue: queue,
                appointments: appointments, inbox: inbox, filter: filter
            )
        )
    }
}

#if DEBUG
#Preview {
    HomePreviewHost {
        NavigationStack { FollowUpsView() }
    }
}
#endif
