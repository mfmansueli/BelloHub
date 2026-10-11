//
//  LanguageRegionView.swift
//  BelloHub
//

import SwiftUI

/// 7.2 Language and region, as Account opens it. Reads the Services from the environment and hands them to
/// `LanguageRegionContentView`, which owns the ViewModel.
struct LanguageRegionView: View {
    @Environment(ProfileService.self) private var profile
    @Environment(BookingSetupService.self) private var bookingSetup

    var body: some View {
        LanguageRegionContentView(
            profile: profile, bookingSetup: bookingSetup,
            regions: (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: [])
        )
    }
}

#Preview {
    let vault = VaultService(repository: nil)
    NavigationStack { LanguageRegionView() }
        .environment(ProfileService(vault: vault))
        .environment(BookingSetupService(vault: vault))
        .environment(InterfaceLanguageService(defaults: .standard, systemDefaults: nil))
}
