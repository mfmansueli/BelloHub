//
//  ImportClientsView.swift
//  BelloHub
//

import SwiftUI

/// 4.6 ImportClients. The sheet that brings clients in from her phone contacts or a spreadsheet (CSV). Other screens
/// present it as a sheet (the Clients list, NewClient, the last step of the setup); it has its own navigation bar.
///
/// It reads the registration gate and her profile from the environment. During the setup there is no profile yet, so
/// the caller passes the region and the client term she just chose; everywhere else both default to her profile.
/// `onViewClients` runs when she taps "View clients" on the result, before the sheet closes.
struct ImportClientsView: View {
    var businessRegionCode: String?
    var clientTerm: ClientTerm?
    let onViewClients: () -> Void

    @Environment(ClientRegistrationService.self) private var registration
    @Environment(ProfileService.self) private var profile
    @State private var viewModel: ImportClientsViewModel?
    @State private var isUnavailable = false

    init(
        businessRegionCode: String? = nil, clientTerm: ClientTerm? = nil, onViewClients: @escaping () -> Void = {}
    ) {
        self.businessRegionCode = businessRegionCode
        self.clientTerm = clientTerm
        self.onViewClients = onViewClients
    }

    var body: some View {
        Group {
            if let viewModel {
                ImportClientsFlowView(
                    viewModel: viewModel, term: clientTerm ?? profile.clientTerm, onViewClients: onViewClients
                )
            } else if isUnavailable {
                unavailable
            } else {
                Palette.bg.ignoresSafeArea()
            }
        }
        .onAppear(perform: makeViewModelIfNeeded)
    }

    /// Only reached if the region table did not load, which a built app never has.
    private var unavailable: some View {
        EmptyState(
            icon: .alert, title: "import.problem.unavailable.title", message: "import.problem.unavailable.message"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .accessibilityIdentifier("importClients.unavailable")
    }

    /// Built once the environment is readable (a view cannot read it in `init`).
    private func makeViewModelIfNeeded() {
        guard viewModel == nil else { return }
        let regions = (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: [])
        let locale = Locale.current
        guard let region = ImportRegion.preset(
            code: businessRegionCode ?? profile.profile?.regionCode, in: regions,
            deviceRegion: locale.region?.identifier, languageCode: locale.language.languageCode?.identifier
        ) else {
            isUnavailable = true
            return
        }
        let services = ImportDependencies.make()
        viewModel = ImportClientsViewModel(
            registrar: registration, region: region, regions: regions,
            contacts: services.contacts, files: services.files, settings: services.settings
        )
    }
}

#if DEBUG
#Preview {
    let vault = VaultService(repository: InMemoryClientRecordRepository())
    return ImportClientsView()
        .environment(ClientRegistrationService(vault: vault))
        .environment(ProfileService(vault: vault))
}
#endif
