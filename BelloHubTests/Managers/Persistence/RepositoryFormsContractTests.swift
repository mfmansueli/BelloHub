//
//  RepositoryFormsContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Repository contract: health form templates, patch tests, guardian consent", .serialized)
struct RepositoryFormsContractTests {
    private let fixture = ContractFixture()
    private var clock: MutableClock { fixture.clock }

    private func seeded(_ flavor: RepositoryFlavor) throws -> (any ClientRecordRepository, Client) {
        try fixture.seeded(flavor)
    }

    private func patchTest(
        _ client: Client, product: String = "Calming serum", daysAgo: Int = 0, result: PatchTestResult = .noReaction
    ) -> PatchTest {
        PatchTest(
            id: UUID(), clientID: client.id, testedAt: TestClock.days(-daysAgo), observedHours: 24,
            product: product, area: "Inner arm", result: result, notes: "Sentinel-NOTES"
        )
    }

    // MARK: - Templates

    @Test("Template versions round-trip, oldest first, and the current one is the highest",
          arguments: RepositoryFlavor.allCases)
    func templatesRoundTrip(flavor: RepositoryFlavor) async throws {
        let (repository, _) = try seeded(flavor)
        #expect(try await repository.healthFormTemplates().isEmpty)
        let second = makeHealthTemplate(version: 2, keys: ["allergies", "notes"], months: 6)
        let first = makeHealthTemplate(version: 1)
        try await repository.save(second)
        try await repository.save(first)

        let stored = try await repository.healthFormTemplates()
        #expect(stored == [first, second])
        #expect(HealthFormTemplateRules.current(of: stored) == second)
    }

    @Test("A stored version keeps its questions: saving it again with others is refused, with the same ones is fine",
          arguments: RepositoryFlavor.allCases)
    func versionIsLocked(flavor: RepositoryFlavor) async throws {
        let (repository, _) = try seeded(flavor)
        let original = makeHealthTemplate(version: 1)
        try await repository.save(original)

        var otherQuestions = original
        otherQuestions.questionKeys = ["allergies"]
        await #expect(throws: FormTemplateError.versionLocked) { try await repository.save(otherQuestions) }
        #expect(try await repository.healthFormTemplates() == [original])

        var newMonths = original
        newMonths.reviewEveryMonths = 3
        try await repository.save(newMonths)
        #expect(try await repository.healthFormTemplates() == [newMonths])
    }

    @Test("The first use stores the default as version 1, once, and later calls return what is stored",
          arguments: RepositoryFlavor.allCases)
    func currentStoresTheDefault(flavor: RepositoryFlavor) async throws {
        let (repository, _) = try seeded(flavor)
        let catalog = makeHealthCatalog()

        let first = try await repository.currentHealthFormTemplate(
            catalog: catalog, professions: [.esthetician], now: TestClock.now
        )
        #expect(first.version == 1 && first.questionKeys == ["allergies", "medication", "pregnancy", "notes"])
        #expect(try await repository.healthFormTemplates() == [first])

        // A different profession or time now changes nothing: version 1 is already stored.
        let again = try await repository.currentHealthFormTemplate(
            catalog: catalog, professions: [.hair], now: TestClock.days(5)
        )
        #expect(again == first)
        #expect(try await repository.healthFormTemplates().count == 1)
    }

    // MARK: - Patch tests

    @Test("Patch tests round-trip, newest first, and each client sees only her own",
          arguments: RepositoryFlavor.allCases)
    func patchTestsRoundTrip(flavor: RepositoryFlavor) async throws {
        let (repository, ana) = try seeded(flavor)
        let bia = Client(name: "Bia", createdAt: clock.now)
        try await repository.save(ana)
        try await repository.save(bia)
        let older = patchTest(ana, product: "Glycolic acid 10%", daysAgo: 60, result: .mildReaction)
        let newer = patchTest(ana, daysAgo: 2)
        try await repository.save(older)
        try await repository.save(newer)
        try await repository.save(patchTest(bia))

        let stored = try await repository.patchTests(for: ana.id)
        #expect(stored == [newer, older])
        #expect(stored.last?.result == .mildReaction && stored.first?.notes == "Sentinel-NOTES")
        #expect(try await repository.patchTests(for: bia.id).count == 1)
    }

    @Test("Saving a patch test again updates it instead of adding a second one", arguments: RepositoryFlavor.allCases)
    func patchTestUpsert(flavor: RepositoryFlavor) async throws {
        let (repository, ana) = try seeded(flavor)
        try await repository.save(ana)
        var entry = patchTest(ana)
        try await repository.save(entry)
        entry.result = .reaction
        try await repository.save(entry)

        let stored = try await repository.patchTests(for: ana.id)
        #expect(stored.count == 1 && stored.first?.result == .reaction)
    }

    @Test("Deleting a client deletes her patch tests, and only hers", arguments: RepositoryFlavor.allCases)
    func deleteCascades(flavor: RepositoryFlavor) async throws {
        let (repository, ana) = try seeded(flavor)
        let bia = Client(name: "Bia", createdAt: clock.now)
        try await repository.save(ana)
        try await repository.save(bia)
        try await repository.save(patchTest(ana))
        try await repository.save(patchTest(bia))

        try await repository.deleteClient(id: ana.id)

        #expect(try await repository.patchTests(for: ana.id).isEmpty)
        #expect(try await repository.patchTests(for: bia.id).count == 1)
    }

    // MARK: - Guardian consent record and a minor's form

    @Test("A guardian consent record and a minor's form round-trip (D17, D55)", arguments: RepositoryFlavor.allCases)
    func guardianConsent(flavor: RepositoryFlavor) async throws {
        let (repository, client) = try seeded(flavor)
        try await repository.save(client)
        let consent = ConsentRecord(
            id: UUID(), clientID: client.id, kind: .guardian, isSigned: true, signedAt: clock.now, createdAt: clock.now,
            label: "Signed by Rita Costa, paper form"
        )
        let form = makeHealthForm(clientID: client.id, answers: ["allergies": .choices(["latex"])], isForMinor: true)
        try await repository.save(consent)
        try await repository.save(form)

        let storedConsent = try #require(try await repository.consents(for: client.id).first)
        #expect(storedConsent == consent && storedConsent.kind == .guardian)
        let storedForm = try #require(try await repository.healthForms(for: client.id).first)
        #expect(storedForm.isForMinor && storedForm.minorName == "Ana Costa")
        #expect(storedForm.answers["allergies"] == .choices(["latex"]))
    }

    @Test("A consent kind a newer version wrote reads as a treatment consent instead of failing")
    func unknownConsentKind() throws {
        let json = #"{"id":"6E1F0000-0000-4000-8000-000000000001","clientID":"6E1F0000-0000-4000-8000-000000000002","# +
            #""kind":"somethingNew","isSigned":true,"signedAt":0,"createdAt":0}"#
        let consent = try JSONDecoder().decode(ConsentRecord.self, from: Data(json.utf8))
        #expect(consent.kind == .treatment)
    }
}
