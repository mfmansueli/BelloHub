//
//  BookingRequestView.swift
//  BelloHub
//

import SwiftUI

/// 2.10 BookingRequest, pushed with `AgendaRoute.bookingRequest` (from Alerts). It reads the Services from the
/// environment and hands them to `BookingRequestContentView`, which owns the ViewModel.
struct BookingRequestView: View {
    let bookingID: String
    @Environment(BookingSyncService.self) private var sync
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(BookingSetupService.self) private var bookingSetup

    var body: some View {
        BookingRequestContentView(
            viewModel: BookingRequestViewModel(
                bookingID: bookingID, sync: sync, vault: vault,
                link: bookingSetup.setup.slug.map { BookingLink(slug: $0) }
            ),
            settings: CalendarSettings(profile: profile.profile)
        )
    }
}
