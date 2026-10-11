//
//  QuickRepliesView.swift
//  BelloHub
//

import SwiftUI

/// 6.9 Quick replies, as the More tab opens it. It only reads the Services the screen needs from the environment and
/// hands them to `QuickRepliesContentView`, which owns the ViewModel: a View cannot read the environment in its
/// `init`, and the More tab pushes every screen with a plain `init()`.
struct QuickRepliesView: View {
    @Environment(BookingSetupService.self) private var bookingSetup
    @Environment(ProfileService.self) private var profile

    var body: some View {
        QuickRepliesContentView(service: bookingSetup, profile: profile.profile)
    }
}

#Preview {
    NavigationStack { QuickRepliesView() }
        .environment(BookingSetupService(vault: VaultService(repository: nil)))
        .environment(ProfileService(vault: VaultService(repository: nil)))
}
