//
//  ImportClientsPreviews.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// Previews of the import steps. The ViewModel is real, fed by the same fixtures the UI tests use (`-uiContacts four`,
/// `-uiSpreadsheet clients`) over an in-memory vault, so what Xcode shows is what the flow does.
@MainActor
private enum ImportPreviewRig {
    struct Rig {
        let model: ImportClientsViewModel
        let registration: ClientRegistrationService
        let profile: ProfileService
    }

    static func make() -> Rig {
        let vault = VaultService(repository: InMemoryClientRecordRepository())
        let registration = ClientRegistrationService(vault: vault)
        let regions = (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: [])
        let region = regions.preset(for: "BR") ?? regions.presets[0]
        let model = ImportClientsViewModel(
            registrar: registration, region: region, regions: regions,
            contacts: FixtureContactsImporter.fixture(named: "four"),
            files: FixtureImportFileReader.fixture(named: "clients")
        )
        return Rig(model: model, registration: registration, profile: ProfileService(vault: vault))
    }
}

#Preview("Sources") {
    let rig = ImportPreviewRig.make()
    return NavigationStack { ImportSourcesView(viewModel: rig.model, term: .client) }
        .environment(rig.registration)
        .environment(rig.profile)
}

#Preview("Choose contacts") {
    let rig = ImportPreviewRig.make()
    return NavigationStack { ImportChooseView(viewModel: rig.model, term: .client) }
        .task { await rig.model.pickContacts() }
        .environment(rig.registration)
        .environment(rig.profile)
}

#Preview("Mapping") {
    let rig = ImportPreviewRig.make()
    return NavigationStack { ImportMappingView(viewModel: rig.model) }
        .task { await rig.model.openSpreadsheet(at: URL(fileURLWithPath: "/tmp/clients.csv")) }
        .environment(rig.registration)
        .environment(rig.profile)
}

#Preview("Result") {
    let rig = ImportPreviewRig.make()
    return NavigationStack { ImportResultView(viewModel: rig.model, term: .patient, onViewClients: {}) }
        .task {
            await rig.model.pickContacts()
            await rig.model.importSelected()
        }
        .environment(rig.registration)
        .environment(rig.profile)
}
#endif
