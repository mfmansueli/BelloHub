//
//  ImportClientsViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The contacts path of the import ViewModel: choosing, selecting, importing, the result and the free registrations.
/// The spreadsheet path is in `ImportClientsViewModelSpreadsheetTests`.
@MainActor
@Suite("ImportClientsViewModel")
struct ImportClientsViewModelTests {
    private func makeContact(_ name: String, phone: String? = nil) -> ImportCandidate {
        ImportViewModelRig.makeContact(name, phone: phone)
    }

    // MARK: - Contacts

    @Test("Picked contacts are listed by name, all selected, and the ones that cannot be imported are set apart")
    func contactsAreListed() async throws {
        let rig = try ImportViewModelRig(contacts: [
            makeContact("Carla", phone: "+5511900000003"), makeContact("Ana", phone: "+5511900000001"),
            makeContact("", phone: "+5511900000002"), makeContact("Bia", phone: "123")
        ])

        await rig.model.pickContacts()

        #expect(rig.model.step == .choose)
        #expect(rig.model.source == .contacts)
        #expect(rig.model.readyEntries.map(\.displayName) == ["Ana", "Carla"])
        #expect(rig.model.skippedEntries.map(\.issue) == [.nameMissing, .invalidPhone])
        #expect(rig.model.selection.count == 2, "everyone who can be imported starts selected")
        #expect(rig.contacts.pickCount == 1)
    }

    @Test("A cancelled picker leaves the sources screen as it was")
    func cancelledPicker() async throws {
        let rig = try ImportViewModelRig(contacts: [])

        await rig.model.pickContacts()

        #expect(rig.model.step == .sources)
        #expect(rig.model.problem == nil)
    }

    @Test("Restricted contacts explain themselves and never open the picker")
    func restrictedContacts() async throws {
        let rig = try ImportViewModelRig(contacts: [makeContact("Ana")])
        rig.contacts.access = .restricted

        await rig.model.pickContacts()

        #expect(rig.model.problem == .contactsRestricted)
        #expect(rig.model.step == .sources)
        #expect(rig.contacts.pickCount == 0)

        rig.model.openSettings()
        #expect(rig.settings.openCount == 1)
    }

    // MARK: - Choosing

    @Test("Select all and clear toggle the whole list, and a row toggles itself")
    func selection() async throws {
        let rig = try ImportViewModelRig(contacts: [makeContact("Ana"), makeContact("Bia"), makeContact("Carla")])
        await rig.model.pickContacts()
        let model = rig.model
        #expect(model.allSelected && model.canImport)

        model.toggleAll()
        #expect(model.selection.isEmpty && !model.canImport && !model.allSelected)

        model.toggleAll()
        #expect(model.allSelected)

        model.toggle("contact-Bia")
        #expect(!model.isSelected("contact-Bia") && model.selection.count == 2 && !model.allSelected)
        model.toggle("contact-Bia")
        #expect(model.isSelected("contact-Bia"))
    }

    @Test("Only the selected clients are imported, in list order, as imported clients with new ids")
    func importsTheSelection() async throws {
        let rig = try ImportViewModelRig(contacts: [
            makeContact("Carla", phone: "+5511900000003"), makeContact("Ana", phone: "+5511900000001"),
            makeContact("Bia", phone: "+5511900000002")
        ])
        await rig.model.pickContacts()
        rig.model.toggle("contact-Bia")
        rig.registrar.importResult = ClientImportResult(registered: 2)

        await rig.model.importSelected()

        let batch = try #require(rig.registrar.imported.first)
        #expect(rig.registrar.imported.count == 1)
        #expect(batch.map(\.name) == ["Ana", "Carla"])
        #expect(batch.allSatisfy { $0.source == .importedClients })
        #expect(Set(batch.map(\.id)).count == 2)
        #expect(batch.first?.phoneE164 == "+5511900000001")
        #expect(rig.model.step == .result)
    }

    @Test("Nothing is imported when nothing is selected")
    func nothingSelected() async throws {
        let rig = try ImportViewModelRig(contacts: [makeContact("Ana")])
        await rig.model.pickContacts()
        rig.model.toggleAll()

        await rig.model.importSelected()

        #expect(rig.registrar.imported.isEmpty)
        #expect(rig.model.step == .choose)
    }

    // MARK: - Result

    @Test("The result carries the gate's counts plus the rows that never reached it")
    func resultAddsTheMalformedRows() async throws {
        let rig = try ImportViewModelRig(contacts: [
            makeContact("Ana"), makeContact(""), makeContact("Bia", phone: "123")
        ])
        await rig.model.pickContacts()
        rig.registrar.importResult = ClientImportResult(registered: 1, duplicates: 0, malformed: 0, blocked: 0)

        await rig.model.importSelected()

        #expect(rig.model.result == ClientImportResult(registered: 1, duplicates: 0, malformed: 2, blocked: 0))
    }

    @Test("Rows the free registrations left out open the paywall on request")
    func blockedRowsOfferThePaywall() async throws {
        let rig = try ImportViewModelRig(contacts: (1...5).map { makeContact("Person \($0)") }, ledgerCount: 8)
        await rig.model.pickContacts()
        rig.registrar.importResult = ClientImportResult(registered: 2, duplicates: 0, malformed: 0, blocked: 3)

        await rig.model.importSelected()
        #expect(rig.model.result?.blocked == 3)
        #expect(!rig.model.isPaywallPresented)

        rig.model.showPaywall()
        #expect(rig.model.isPaywallPresented)
    }

    @Test("When the vault fails the import says so, keeps the choice and stays where it was")
    func importFailure() async throws {
        let catalog = try RegionCatalogTests.bundled()
        let model = ImportClientsViewModel(
            registrar: FailingClientRegistrar(), region: try #require(catalog.preset(for: "BR")), regions: catalog,
            contacts: FakeContactsImporter(contacts: [makeContact("Ana"), makeContact("Bia")]),
            files: FakeImportFileReader(), settings: FakeSettingsOpener(), now: { TestClock.now }
        )
        await model.pickContacts()

        await model.importSelected()

        #expect(model.problem == .importFailed)
        #expect(model.step == .choose)
        #expect(model.selection.count == 2)
        #expect(model.result == nil)
        #expect(!model.isWorking)
    }

    // MARK: - The free registrations

    @Test("A batch larger than the free slots says how many go through and that the rest need a plan")
    func partialFit() async throws {
        let rig = try ImportViewModelRig(contacts: (1...10).map { makeContact("Person \($0)") }, ledgerCount: 6)
        await rig.model.pickContacts()

        let fit = rig.model.fit

        #expect(fit == ImportBatchFit(selected: 10, usage: rig.model.usage))
        #expect(fit.willImport == 4 && fit.waiting == 6 && fit.needsPlan)

        rig.model.toggleAll()
        rig.model.toggle("contact-Person 1")
        #expect(rig.model.fit.willImport == 1 && !rig.model.fit.needsPlan)
    }

    @Test("With a plan nothing waits")
    func planFit() async throws {
        let rig = try ImportViewModelRig(
            contacts: (1...10).map { makeContact("Person \($0)") }, ledgerCount: 10, hasPlan: true
        )
        await rig.model.pickContacts()

        #expect(rig.model.fit.willImport == 10 && !rig.model.fit.needsPlan)
    }

    @Test("Opening the screen refreshes the counter")
    func startRefreshesUsage() async throws {
        let rig = try ImportViewModelRig()

        await rig.model.start()

        #expect(rig.registrar.refreshCount == 1)
    }

    // MARK: - Display

    @Test("A phone is shown the way people write it, kept left-to-right")
    func phoneText() async throws {
        let rig = try ImportViewModelRig(contacts: [makeContact("Ana", phone: "(11) 98765-4321"), makeContact("Bia")])
        await rig.model.pickContacts()

        let withPhone = try #require(rig.model.phoneText(for: rig.model.readyEntries[0]))

        #expect(BidiIsolate.strip(withPhone) == "+55 (11) 98765-4321")
        #expect(withPhone.hasPrefix(String(BidiIsolate.leftToRightIsolate)))
        #expect(rig.model.phoneText(for: rig.model.readyEntries[1]) == nil)
    }
}
