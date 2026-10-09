//
//  FollowUpsView.swift
//  BelloHub
//

import SwiftUI

/// 2.7 Follow-ups, pushed from Home and Alerts (`AgendaRoute.followUps`). It reads the Services from the environment
/// and hands them to `FollowUpsContentView`, which owns the ViewModel.
struct FollowUpsView: View {
    @Environment(AgendaDigestService.self) private var digest
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(ProfileService.self) private var profile
    @Environment(MessageService.self) private var messages

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        FollowUpsContentView(
            viewModel: FollowUpsViewModel(
                settings: settings, digest: digest, bookingSetup: bookingSetup, messages: messages
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
