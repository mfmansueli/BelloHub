//
//  AvailabilityView.swift
//  BelloHub
//

import SwiftUI

/// 6.5 Availability, as the More tab opens it. It only reads the Services the screen needs from the environment and
/// hands them to `AvailabilityContentView`, which owns the ViewModel: a View cannot read the environment in its
/// `init`, and the More tab pushes every screen with a plain `init()`.
struct AvailabilityView: View {
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(ProfileService.self) private var profile

    var body: some View {
        AvailabilityContentView(
            service: bookingSetup,
            timeZoneID: profile.profile?.timeZoneID ?? TimeZone.current.identifier,
            regionCode: profile.profile?.regionCode
        )
    }
}

#Preview {
    NavigationStack { AvailabilityView() }
        .environment(BookingSetupService(vault: VaultService(repository: nil)))
        .environment(ProfileService(vault: VaultService(repository: nil)))
}
