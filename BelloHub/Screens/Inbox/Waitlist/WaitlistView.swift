//
//  WaitlistView.swift
//  BelloHub
//

import SwiftUI

/// 2.9 Waitlist, pushed with `AgendaRoute.waitlist` (from Alerts). It reads the Services from the environment and
/// hands them to `WaitlistContentView`, which owns the ViewModel.
struct WaitlistView: View {
    @Environment(BookingSyncService.self) private var sync
    @Environment(ProfileService.self) private var profile
    @Environment(VaultService.self) private var vault

    var body: some View {
        let settings = CalendarSettings(profile: profile.profile)
        WaitlistContentView(
            viewModel: WaitlistViewModel(sync: sync, timeZone: settings.timeZone, vault: vault), settings: settings
        )
        // Her zone and week start are only known once her profile is read: new ones build a new ViewModel.
        .id(settings)
    }
}
