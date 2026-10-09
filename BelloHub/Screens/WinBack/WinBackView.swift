//
//  WinBackView.swift
//  BelloHub
//

import SwiftUI

/// 2.8 Win back, pushed from Home, Week at a glance and Alerts (`AgendaRoute.winBack`). It reads the Services from the
/// environment and hands them to `WinBackContentView`, which owns the ViewModel.
struct WinBackView: View {
    @Environment(AgendaDigestService.self) private var digest
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(ProfileService.self) private var profile
    @Environment(MessageService.self) private var messages

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        WinBackContentView(
            viewModel: WinBackViewModel(
                settings: settings, digest: digest, bookingSetup: bookingSetup, messages: messages
            )
        )
    }
}

#if DEBUG
#Preview {
    HomePreviewHost {
        NavigationStack { WinBackView() }
    }
}
#endif
