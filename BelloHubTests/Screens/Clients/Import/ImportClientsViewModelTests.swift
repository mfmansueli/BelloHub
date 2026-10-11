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

    @Test("A batch larger than the free slots says how many go through now and how many wait for a plan")
    func partialPlan() async throws {
        let rig = try ImportViewModelRig(contacts: (1...10).map { makeContact("Person \($0)") }, ledgerCount: 6)
        await rig.model.pickContacts()

        let plan = rig.model.plan

        #expect(plan.newClients == 10 && plan.registeredNow == 4 && plan.waiting == 6 && plan.kind == .partlyFree)

        rig.model.toggleAll()
        rig.model.toggle("contact-Person 1")
        #expect(rig.model.plan.registeredNow == 1 && rig.model.plan.kind == .allFree)
    }

    @Test("With a plan nothing waits")
    func planUnlimited() async throws {
        let rig = try ImportViewModelRig(
            contacts: (1...10).map { makeContact("Person \($0)") }, ledgerCount: 10, hasPlan: true
        )
        await rig.model.pickContacts()

        #expect(rig.model.plan.registeredNow == 10 && !rig.model.plan.needsPlan && rig.model.plan.kind == .unlimited)
    }

    @Test("People already in her list are marked, start unticked and are not counted as new")
    func duplicatesAreMarked() async throws {
        let rig = try ImportViewModelRig(contacts: [
            makeContact("Ana", phone: "+5511900000001"), makeContact("Bia", phone: "+5511900000002")
        ])
        rig.registrar.known = [Client(name: "Ana Costa", phoneE164: "+5511900000001", createdAt: TestClock.now)]

        await rig.model.pickContacts()

        let ana = try #require(rig.model.readyEntries.first { $0.displayName == "Ana" })
        #expect(rig.model.isAlreadyInList(ana))
        #expect(!rig.model.isSelected(ana.id), "a duplicate would be skipped, so it starts unticked")
        #expect(rig.model.plan.newClients == 1 && rig.model.plan.alreadyInList == 0)

        rig.model.toggle(ana.id)
        #expect(rig.model.plan.newClients == 1 && rig.model.plan.alreadyInList == 1, "ticked, it shows as skipped")
    }

    @Test("When her list cannot be read every row counts as new and the plan says duplicates were not checked")
    func unreadableList() async throws {
        let rig = try ImportViewModelRig(contacts: [makeContact("Ana"), makeContact("Bia")])
        rig.registrar.known = nil

        await rig.model.pickContacts()

        #expect(rig.model.selection.count == 2)
        #expect(!rig.model.plan.checkedDuplicates && rig.model.plan.newClients == 2)
    }

    @Test("Trying a small group selects only the first new people, passing over the ones already in her list")
    func trialGroup() async throws {
        let rig = try ImportViewModelRig(contacts: (1...8).map {
            makeContact("Person \($0)", phone: "+551190000000\($0)")
        }, ledgerCount: 6)
        rig.registrar.known = [Client(name: "Old", phoneE164: "+5511900000001", createdAt: TestClock.now)]
        await rig.model.pickContacts()

        #expect(rig.model.trialChoices == [3, 4, 5], "3 and 5 are smaller than the 7 new; 4 is what is free")

        rig.model.selectTrial(size: 3)

        #expect(rig.model.selection == ["contact-Person 2", "contact-Person 3", "contact-Person 4"])
        #expect(rig.model.plan.kind == .allFree && rig.model.plan.freeLeftAfter == 1)
    }

    @Test("Once a plan is active, the rows that waited are imported again and added to the result")
    func importRestAfterPlan() async throws {
        let rig = try ImportViewModelRig(contacts: (1...5).map { makeContact("Person \($0)") }, ledgerCount: 8)
        await rig.model.pickContacts()
        rig.registrar.importResult = ClientImportResult(registered: 2, blocked: 3)
        await rig.model.importSelected()
        #expect(!rig.model.canImportRest, "without a plan the paywall is offered instead")

        rig.registrar.usage = RegistrationUsage(quota: RegistrationQuota(ledgerCount: 10, hasActivePlan: true))
        rig.registrar.importResult = ClientImportResult(registered: 3, duplicates: 2)
        #expect(rig.model.canImportRest)
        await rig.model.importRest()

        #expect(rig.registrar.imported.count == 2)
        #expect(rig.registrar.imported.last?.count == 5, "the same selection; the gate skips the two already added")
        #expect(rig.model.result?.registered == 5 && rig.model.result?.blocked == 0)
        #expect(!rig.model.canImportRest)
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
