//
//  CredentialsViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("CredentialsViewModel")
struct CredentialsViewModelTests {
    private let english = Locale(identifier: "en_US")
    private let zone = TimeZone(identifier: "UTC") ?? .current

    private func makeModel(_ repository: FakeCatalogRepository) -> CredentialsViewModel {
        CredentialsViewModel(repository: repository, locale: english, timeZone: zone, now: { TestClock.now })
    }

    private func draft(_ title: String, year: String = "") -> CredentialDraft {
        var draft = CredentialDraft()
        draft.title = title
        draft.yearText = year
        return draft
    }

    private func training(_ title: String, position: Int = 0, shown: Bool = true) -> Credential {
        Credential(title: title, showOnBookingPage: shown, position: position)
    }

    @Test("Loading reads the credentials and puts the registration number in its field")
    func load() async {
        let repository = FakeCatalogRepository()
        await repository.seed(credentials: [
            training("A"), Credential(kind: .registration, title: "", registrationNumber: "COREN 1", position: 1)
        ])
        let model = makeModel(repository)

        await model.loadAsync()

        #expect(model.trainings.map(\.title) == ["A"] && model.registrationText == "COREN 1")
        #expect(model.hasLoaded && !model.showsEmptyState && model.errorMessage == nil)
    }

    @Test("With no course or certificate the list says so, but the rest of the screen stays")
    func emptyList() async {
        let model = makeModel(FakeCatalogRepository())
        await model.loadAsync()
        #expect(model.showsEmptyState && model.showsOnPage)
    }

    @Test("A failed read says so and shows no empty state")
    func readFailure() async {
        let repository = FakeCatalogRepository()
        await repository.setFailsReads(true)
        let model = makeModel(repository)
        await model.loadAsync()
        #expect(model.errorMessage != nil && !model.showsEmptyState)
    }

    @Test("Adding stores the credential with the year and the page switch as it stands")
    func add() async throws {
        let repository = FakeCatalogRepository()
        let model = makeModel(repository)
        await model.loadAsync()
        await model.setShowsOnPageAsync(false)

        let saved = await model.save(draft("Biosafety training", year: "2024"), editing: nil)

        #expect(saved)
        let stored = try #require(await repository.storedCredentials().first)
        #expect(stored.title == "Biosafety training" && stored.year == 2024 && !stored.showOnBookingPage)
    }

    @Test("A year in the future or a missing name is refused and nothing is written")
    func refused() async {
        let repository = FakeCatalogRepository()
        let model = makeModel(repository)
        await model.loadAsync()

        #expect(await model.save(draft("Course", year: "2030"), editing: nil) == false)
        #expect(await model.save(draft(""), editing: nil) == false)
        #expect(await repository.writeCount == 0)
        #expect(model.issues(in: draft("Course", year: "2030")) == [.yearInvalid])
    }

    @Test("The page switch changes every credential in one write and reads back")
    func pageSwitch() async {
        let repository = FakeCatalogRepository()
        await repository.seed(credentials: [
            training("A"), training("B", position: 1),
            Credential(kind: .registration, title: "", registrationNumber: "1", position: 2)
        ])
        let model = makeModel(repository)
        await model.loadAsync()
        #expect(model.showsOnPage)

        await model.setShowsOnPageAsync(false)

        #expect(!model.showsOnPage)
        #expect(await repository.storedCredentials().allSatisfy { !$0.showOnBookingPage })
        #expect(await repository.bulkWriteCount == 1)

        await model.setShowsOnPageAsync(true)
        let allShown = await repository.storedCredentials().allSatisfy(\.showOnBookingPage)
        #expect(model.showsOnPage && allShown)
    }

    @Test("With no credential the switch is remembered, and the next one added follows it")
    func pageSwitchWhenEmpty() async throws {
        let repository = FakeCatalogRepository()
        let model = makeModel(repository)
        await model.loadAsync()

        await model.setShowsOnPageAsync(false)
        let writes = await repository.writeCount
        #expect(!model.showsOnPage && writes == 0)

        await model.save(draft("Course"), editing: nil)
        #expect(try #require(await repository.storedCredentials().first).showOnBookingPage == false)
    }

    @Test("A failed switch leaves it as it was and says so")
    func pageSwitchFailure() async {
        let repository = FakeCatalogRepository()
        await repository.seed(credentials: [training("A")])
        let model = makeModel(repository)
        await model.loadAsync()
        await repository.setFailsWrites(true)

        await model.setShowsOnPageAsync(false)

        #expect(model.showsOnPage && model.saveErrorMessage != nil)
    }

    @Test("Typing a registration number stores it, changing it updates it and emptying it removes it")
    func registration() async {
        let repository = FakeCatalogRepository()
        let model = makeModel(repository)
        await model.loadAsync()

        model.registrationText = "COREN 123"
        await model.commitRegistrationAsync()
        #expect(await repository.storedCredentials().map(\.registrationNumber) == ["COREN 123"])
        #expect(model.registration?.registrationNumber == "COREN 123" && model.trainings.isEmpty)

        model.registrationText = "COREN 456"
        await model.commitRegistrationAsync()
        #expect(await repository.storedCredentials().count == 1)
        #expect(await repository.storedCredentials().first?.registrationNumber == "COREN 456")

        model.registrationText = "  "
        await model.commitRegistrationAsync()
        #expect(await repository.storedCredentials().isEmpty && model.registration == nil)
    }

    @Test("Leaving the field as it was writes nothing")
    func registrationUnchanged() async {
        let repository = FakeCatalogRepository()
        await repository.seed(credentials: [Credential(kind: .registration, title: "", registrationNumber: "1")])
        let model = makeModel(repository)
        await model.loadAsync()

        await model.commitRegistrationAsync()

        #expect(await repository.writeCount == 0)
    }

    @Test("A number that is too long is flagged and not stored; a failed write says so")
    func registrationProblems() async {
        let repository = FakeCatalogRepository()
        let model = makeModel(repository)
        await model.loadAsync()

        model.registrationText = String(repeating: "9", count: 41)
        #expect(!model.isRegistrationValid)
        await model.commitRegistrationAsync()
        #expect(await repository.writeCount == 0)

        model.registrationText = "123"
        await repository.setFailsWrites(true)
        await model.commitRegistrationAsync()
        #expect(model.saveErrorMessage != nil && model.registration == nil)
    }

    @Test("Deleting removes only that credential")
    func delete() async throws {
        let repository = FakeCatalogRepository()
        await repository.seed(credentials: [training("A"), training("B", position: 1)])
        let model = makeModel(repository)
        await model.loadAsync()

        await model.delete(try #require(model.trainings.first))

        let stored = await repository.storedCredentials().map(\.title)
        #expect(model.trainings.map(\.title) == ["B"] && stored == ["B"])
    }

    @Test("The year check uses the Gregorian calendar even under an Arabic regional calendar")
    func gregorianYear() {
        let model = CredentialsViewModel(
            repository: FakeCatalogRepository(), locale: Locale(identifier: "ar_SA@calendar=islamic-umalqura"),
            timeZone: zone, now: { TestClock.now }
        )
        #expect(model.issues(in: draft("Course", year: "2026")).isEmpty, "Islamic 1448 must not be read as the year")
    }
}
