//
//  BookingSettingsView.swift
//  BelloHub
//

import SwiftUI

/// 6.7 Booking page, as the More tab opens it. It only reads the Services the screen needs from the environment and
/// hands them to `BookingSettingsContentView`, which owns the ViewModel: a View cannot read the environment in its
/// `init`, and the More tab pushes every screen with a plain `init()`.
struct BookingSettingsView: View {
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(ProfileService.self) private var profile
    @Environment(PublishingService.self) private var publishing

    var body: some View {
        BookingSettingsContentView(service: bookingSetup, publishing: publishing, profile: profile.profile)
    }
}

#Preview {
    NavigationStack { BookingSettingsView() }
        .environment(BookingSetupService(vault: VaultService(repository: nil)))
        .environment(ProfileService(vault: VaultService(repository: nil)))
        .environment(PublishingService.preview)
}
