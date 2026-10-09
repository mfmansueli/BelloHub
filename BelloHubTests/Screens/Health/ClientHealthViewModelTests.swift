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
        let legal: FakeLegalTextLibrary
    }

    private static func legalLibrary() -> FakeLegalTextLibrary {
        FakeLegalTextLibrary(LegalDocument.allCases.map { FakeLegalTextLibrary.text($0) })
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
        let legal = Self.legalLibrary()
        let model = ClientHealthViewModel(
            clientID: client.id, repository: vaultAvailable ? repository : nil, profile: profile,
            catalogProvider: FakeHealthFormCatalogProvider(), legal: legal, locale: Locale(identifier: "en"),
            now: { now }, makeID: { UUID() }
        )
        return Rig(model: model, repository: repository, profile: profile, client: client, legal: legal)
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
        try await rig.repository.save(Consent(
            id: UUID(), clientID: rig.client.id, kind: .treatment, signedAt: TestClock.days(-10),
            textVersion: "2026-10", localeID: "en", typedSignature: "Ana Costa", signatureImage: nil
        ))
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
            catalogProvider: FakeHealthFormCatalogProvider(), legal: rig.legal, locale: Locale(identifier: "en")
        )
        await stranger.load()
        #expect(stranger.errorMessage != nil && !stranger.hasLoaded)

        let noVault = try await makeRig(vaultAvailable: false)
        await noVault.model.load()
        #expect(noVault.model.errorMessage != nil && !noVault.model.hasLoaded)
    }

    // MARK: - Sheets

    @Test("Filling the form stores the template as version 1 first, and opens the sheet with her questions")
    func startFilling() async throws {
        let rig = try await makeRig(professions: [.lash])
        await rig.model.load()

        await rig.model.startFillingAsync()

        let sheet = try #require(rig.model.fillSheet)
        #expect(sheet.template.version == 1)
        #expect(sheet.questions.map(\.key).contains("pregnancy") && sheet.questions.map(\.key).contains("allergies"))
        #expect(try await rig.repository.healthFormTemplates() == [sheet.template])
        #expect(rig.model.currentTemplate == sheet.template)
    }

    @Test("The sheet opens once; and a template that cannot be stored shows an error instead of a sheet")
    func startFillingGuards() async throws {
        let rig = try await makeRig()
        await rig.model.load()
        await rig.repository.fail(.template)

        await rig.model.startFillingAsync()
        #expect(rig.model.fillSheet == nil && rig.model.errorMessage != nil)

        await rig.repository.fail([])
        await rig.model.startFillingAsync()
        let first = try #require(rig.model.fillSheet)
        await rig.model.startFillingAsync()
        #expect(rig.model.fillSheet?.id == first.id)
    }

    @Test("Nothing opens before the screen has loaded")
    func nothingBeforeLoad() async throws {
        let rig = try await makeRig()

        await rig.model.startFillingAsync()

        #expect(rig.model.fillSheet == nil)
    }

    @Test("A form filled in through the sheet shows on the screen after a reload, with its consent")
    func fillAndReload() async throws {
        let rig = try await makeRig()
        await rig.model.load()
        await rig.model.startFillingAsync()
        let sheet = try #require(rig.model.fillSheet)
        for question in sheet.questions {
            switch question.kind {
            case .yesNo: sheet.setYesNo(false, for: question)
            case .choices: sheet.toggleChoice(HealthOption.noneKey, for: question)
            case .text: break
            }
        }
        sheet.draft.agrees = true
        sheet.draft.signature = "Ana Costa"
        await sheet.saveAsync()
        #expect(sheet.didSave)

        await rig.model.load()

        #expect(rig.model.latestForm?.filledBy == .professional && rig.model.consents.count == 1)
        #expect(rig.model.answerRows.contains { $0.key == "medication" && $0.value == "No" })
        guard case .current(let dueAt)? = rig.model.reviewStatus else {
            Issue.record("a form signed just now is current")
            return
        }
        #expect(dueAt > TestClock.now)
    }

    @Test("Recording a patch test and reading a signed text open their own sheets, once")
    func otherSheets() async throws {
        let rig = try await makeRig()
        await rig.model.load()

        rig.model.startPatchTest()
        let patch = try #require(rig.model.patchSheet)
        rig.model.startPatchTest()
        #expect(rig.model.patchSheet?.id == patch.id)

        let consent = Consent(
            id: UUID(), clientID: rig.client.id, kind: .guardian, signedAt: TestClock.now, textVersion: "2026-10",
            localeID: "en", typedSignature: "Rita Costa", signatureImage: nil
        )
        rig.model.open(consent)
        #expect(rig.model.consentSheet?.consent == consent)
        #expect(rig.model.consentSheet?.legalText?.document == .consentGuardian)
    }
}
