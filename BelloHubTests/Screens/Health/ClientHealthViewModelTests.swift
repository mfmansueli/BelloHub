//
//  ClientHealthViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("ClientHealthViewModel")
struct ClientHealthViewModelTests {
    private struct Rig {
        let model: ClientHealthViewModel
        let repository: FlakyHealthRepository
        let profile: ProfileService
        let client: Client
    }

    private func makeRig(
        professions: [ProfessionID] = [.esthetician], now: Date = TestClock.now, vaultAvailable: Bool = true
    ) async throws -> Rig {
        let repository = FlakyHealthRepository()
        let client = Client(name: "Ana Costa", createdAt: TestClock.days(-100))
        try await repository.save(client)
        let profileRepository = InMemoryClientRecordRepository()
        await profileRepository.save(makeHealthProfile(professions: professions))
        let profile = ProfileService(vault: VaultService(repository: profileRepository))
        await profile.load()
        let model = ClientHealthViewModel(
            clientID: client.id, repository: vaultAvailable ? repository : nil, profile: profile,
            catalogProvider: FakeHealthFormCatalogProvider(), photos: FakePhotoProcessing(),
            files: FakeConsentDocumentReader(), locale: Locale(identifier: "en"), now: { now }, makeID: { UUID() }
        )
        return Rig(model: model, repository: repository, profile: profile, client: client)
    }

    private func signedForm(for client: Client, version: Int = 1, daysAgo: Int = 10) -> HealthForm {
        makeHealthForm(
            clientID: client.id, version: version,
            answers: ["allergies": .choices(["fragrance"]), "medication": .no, "pregnancy": .no],
            signedAt: TestClock.days(-daysAgo), filledBy: .client
        )
    }

    // MARK: - Loading

    @Test("Loading brings the client, her forms, consents, patch tests, versions and the catalog")
    func loads() async throws {
        let rig = try await makeRig()
        try await rig.repository.save(signedForm(for: rig.client))
        try await rig.repository.save(makeConsentRecord(clientID: rig.client.id))
        try await rig.repository.save(PatchTest(
            id: UUID(), clientID: rig.client.id, testedAt: TestClock.days(-40), observedHours: 24,
            product: "Serum", area: nil, result: .noReaction, notes: nil
        ))
        try await rig.repository.save(makeHealthTemplate(version: 1, months: 6))

        await rig.model.load()

        #expect(rig.model.hasLoaded && !rig.model.isLoading && rig.model.errorMessage == nil)
        #expect(rig.model.client?.name == "Ana Costa" && rig.model.clientFirstName == "Ana")
        #expect(rig.model.forms.count == 1 && rig.model.consents.count == 1 && rig.model.patchTests.count == 1)
        #expect(rig.model.catalog?.localization == "en")
        #expect(rig.model.reviewMonths == 6)
    }

    @Test("The answers are read against the questions of the version the form was signed on")
    func answerRows() async throws {
        let rig = try await makeRig()
        try await rig.repository.save(makeHealthTemplate(version: 1, keys: ["allergies", "medication", "pregnancy"]))
        try await rig.repository.save(makeHealthTemplate(version: 2, keys: ["allergies"]))
        try await rig.repository.save(signedForm(for: rig.client, version: 1))

        await rig.model.load()

        let rows = rig.model.answerRows
        #expect(rows.map(\.key) == ["allergies", "medication", "pregnancy"])
        #expect(rows.map(\.value) == ["Fragrance", "No", "No"])
        #expect(rig.model.currentTemplate?.version == 2)
    }

    @Test("With no form there are no rows and no review status, and the review period is the default 12 months")
    func noForm() async throws {
        let rig = try await makeRig()

        await rig.model.load()

        #expect(rig.model.latestForm == nil && rig.model.answerRows.isEmpty && rig.model.reviewStatus == nil)
        #expect(rig.model.reviewMonths == 12)
    }

    @Test("The review is current until exactly the period ends, then due (the boundary in the business time zone)")
    func reviewBoundary() async throws {
        let zone = "America/Sao_Paulo"
        let signed = TestClock.date("2026-09-12 14:00", zone: zone)
        let due = TestClock.date("2027-09-12 14:00", zone: zone)

        for (now, expected) in [
            (due.addingTimeInterval(-1), HealthReviewStatus.current(dueAt: due)),
            (due, HealthReviewStatus.due(dueAt: due))
        ] {
            let rig = try await makeRig(now: now)
            try await rig.repository.save(makeHealthForm(clientID: rig.client.id, signedAt: signed))
            await rig.model.load()
            #expect(rig.model.reviewStatus == expected)
        }
    }

    @Test("A failed load says so and keeps what was on screen; a retry recovers")
    func failureAndRetry() async throws {
        let rig = try await makeRig()
        try await rig.repository.save(signedForm(for: rig.client))
        await rig.model.load()
        #expect(rig.model.hasLoaded)

        await rig.repository.fail(.reads)
        await rig.model.load()
        #expect(rig.model.errorMessage != nil && rig.model.hasLoaded && rig.model.forms.count == 1)

        await rig.repository.fail([])
        await rig.model.load()
        #expect(rig.model.errorMessage == nil)
    }

    @Test("A client who is not in the vault, or a vault that is not available, is an error and never a blank screen")
    func unavailable() async throws {
        let rig = try await makeRig()
        let stranger = ClientHealthViewModel(
            clientID: UUID(), repository: rig.repository, profile: rig.profile,
            catalogProvider: FakeHealthFormCatalogProvider(), photos: FakePhotoProcessing(),
            files: FakeConsentDocumentReader(), locale: Locale(identifier: "en")
        )
        await stranger.load()
        #expect(stranger.errorMessage != nil && !stranger.hasLoaded)

        let noVault = try await makeRig(vaultAvailable: false)
        await noVault.model.load()
        #expect(noVault.model.errorMessage != nil && !noVault.model.hasLoaded)
    }

    // MARK: - Folders (D60)

    @Test("Health forms and consents are two folders of the same kind of record")
    func folders() async throws {
        let rig = try await makeRig()
        let form = makeConsentRecord(clientID: rig.client.id, kind: .healthForm, label: "Anamnesis, paper")
        let consent = makeConsentRecord(clientID: rig.client.id, kind: .photos)
        try await rig.repository.save(form)
        try await rig.repository.save(consent)

        await rig.model.load()

        #expect(rig.model.healthForms.map(\.id) == [form.id])
        #expect(rig.model.otherConsents.map(\.id) == [consent.id])
    }

    @Test("Adding a health form opens the record sheet on the health-form kind, signed today, once")
    func startHealthForm() async throws {
        let rig = try await makeRig()
        await rig.model.load()

        rig.model.startHealthForm()

        let sheet = try #require(rig.model.consentSheet)
        #expect(sheet.draft.kind == .healthForm && sheet.draft.isSigned && sheet.draft.signedAt == TestClock.now)
        rig.model.startHealthForm()
        #expect(rig.model.consentSheet?.id == sheet.id)
    }

    @Test("The review counts from the latest signed paper form, or an older answered form when that is later")
    func reviewFromPaper() async throws {
        let rig = try await makeRig()
        try await rig.repository.save(signedForm(for: rig.client, daysAgo: 400))
        try await rig.repository.save(makeConsentRecord(clientID: rig.client.id, kind: .healthForm, daysAgo: 20))
        // A consent of another kind never counts as a health form.
        try await rig.repository.save(makeConsentRecord(clientID: rig.client.id, kind: .treatment, daysAgo: 1))

        await rig.model.load()

        guard case .current(let dueAt)? = rig.model.reviewStatus else {
            Issue.record("a paper form signed 20 days ago is current")
            return
        }
        #expect(dueAt > TestClock.days(330) && dueAt < TestClock.days(350))
    }

    @Test("An unsigned paper form does not count; with only that, the old answered form decides")
    func unsignedPaper() async throws {
        let rig = try await makeRig()
        try await rig.repository.save(signedForm(for: rig.client, daysAgo: 400))
        try await rig.repository.save(
            makeConsentRecord(clientID: rig.client.id, kind: .healthForm, isSigned: false, daysAgo: 5)
        )

        await rig.model.load()

        guard case .due? = rig.model.reviewStatus else {
            Issue.record("the form signed 400 days ago is due")
            return
        }
    }

    @Test("Recording a patch test and adding a consent record open their own sheets, once")
    func otherSheets() async throws {
        let rig = try await makeRig()
        await rig.model.load()

        rig.model.startPatchTest()
        let patch = try #require(rig.model.patchSheet)
        rig.model.startPatchTest()
        #expect(rig.model.patchSheet?.id == patch.id)

        rig.model.startConsent()
        let sheet = try #require(rig.model.consentSheet)
        #expect(!sheet.isEditing && sheet.draft.isSigned && sheet.draft.signedAt == TestClock.now)
        rig.model.startConsent()
        #expect(rig.model.consentSheet?.id == sheet.id)
    }

    @Test("Tapping a consent record opens it for editing, and a saved record shows after a reload")
    func editConsent() async throws {
        let rig = try await makeRig()
        let record = makeConsentRecord(clientID: rig.client.id, kind: .guardian, label: "Rita signed on paper")
        try await rig.repository.save(record)
        await rig.model.load()

        rig.model.open(record)
        let sheet = try #require(rig.model.consentSheet)
        #expect(sheet.isEditing && sheet.existing == record && sheet.draft.label == "Rita signed on paper")
        sheet.draft.isSigned = false
        await sheet.saveAsync()
        rig.model.consentSheet = nil

        await rig.model.load()
        #expect(rig.model.consents.count == 1 && rig.model.consents.first?.isSigned == false)
        #expect(rig.model.consents.first?.id == record.id, "editing updates the same record")
    }

    @Test("Without a vault no consent sheet opens")
    func consentNeedsVault() async throws {
        let rig = try await makeRig(vaultAvailable: false)
        rig.model.startConsent()
        #expect(rig.model.consentSheet == nil)
    }
}
