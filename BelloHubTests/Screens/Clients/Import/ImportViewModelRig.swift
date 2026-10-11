//
//  ImportViewModelRig.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// An `ImportClientsViewModel` wired to fakes, with the fakes kept so a test can script and inspect them. The suites of
/// the import ViewModel share it.
@MainActor
struct ImportViewModelRig {
    let model: ImportClientsViewModel
    let registrar: FakeClientRegistrar
    let contacts: FakeContactsImporter
    let files: FakeImportFileReader
    let settings: FakeSettingsOpener

    static let fileURL = URL(fileURLWithPath: "/tmp/clients.csv")

    /// A spreadsheet with a good row, a bad phone, a missing name and another good row.
    static let sheet = "Nome;Telefone\nAna;(11) 98765-4321\nBia;123\n;(11) 98765-0000\nCarla;(21) 99888-7766"

    init(
        contacts: [ImportCandidate] = [], text: String = "", ledgerCount: Int = 0, hasPlan: Bool = false,
        presetFile: URL? = nil
    ) throws {
        let catalog = try RegionCatalogTests.bundled()
        let brazil = try #require(catalog.preset(for: "BR"))
        let registrar = FakeClientRegistrar()
        registrar.usage = RegistrationUsage(quota: RegistrationQuota(ledgerCount: ledgerCount, hasActivePlan: hasPlan))
        let fakeContacts = FakeContactsImporter(contacts: contacts)
        let files = FakeImportFileReader(text: text, presetFile: presetFile)
        let settings = FakeSettingsOpener()
        self.model = ImportClientsViewModel(
            registrar: registrar, region: brazil, regions: catalog, contacts: fakeContacts, files: files,
            settings: settings, now: { TestClock.now }
        )
        self.registrar = registrar
        self.contacts = fakeContacts
        self.files = files
        self.settings = settings
    }

    /// A contact the picker "returns"; a nil phone is a contact without a number.
    static func makeContact(_ name: String, phone: String? = nil) -> ImportCandidate {
        ImportCandidate(
            id: "contact-\(name)", name: name,
            phoneNumbers: phone.map { [ImportPhoneNumber($0, isMobile: true)] } ?? []
        )
    }
}
