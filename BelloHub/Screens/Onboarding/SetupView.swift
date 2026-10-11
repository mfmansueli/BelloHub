//
//  SetupView.swift
//  BelloHub
//

import SwiftUI

/// The `setup` stage of the app: builds the starting draft from what the phone says, loads the profession catalog of
/// her language and hands both to `OnboardingView`. Kept apart from `RootView` so the ViewModel is made once.
struct SetupView: View {
    @State private var viewModel: OnboardingViewModel?
    let onFinished: @MainActor () -> Void
    let onExit: () -> Void

    init(
        profile: ProfileService, regions: RegionCatalog, suggestedName: String? = nil,
        onFinished: @escaping @MainActor () -> Void, onExit: @escaping () -> Void
    ) {
        self.onFinished = onFinished
        self.onExit = onExit
        // The region and time zone come from the iPhone; the business language starts as the language she reads the
        // app in, and the catalog (professions, services, fields she reads now) is in that language too.
        let interface = InterfaceLocale.localization
        var draft = OnboardingDraft.initial(
            regions: regions, deviceRegion: Locale.current.region?.identifier,
            languageCode: interface.languageCode,
            preferredLanguages: [interface.rawValue], deviceTimeZoneID: TimeZone.current.identifier
        )
        // Apple gives the name once, on the first sign-in; she can edit it on the About-you step.
        if let suggestedName { draft.displayName = suggestedName }
        let catalog = try? ProfessionCatalog.loadBundled(localization: interface)
        _viewModel = State(initialValue: catalog.map {
            OnboardingViewModel(draft: draft, catalog: $0, profile: profile, regions: regions, onFinished: onFinished)
        })
    }

    var body: some View {
        if let viewModel {
            OnboardingView(viewModel: viewModel, onExit: onExit)
        } else {
            StorageUnavailableView()
        }
    }
}
