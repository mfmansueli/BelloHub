//
//  RepositoryBusinessContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Repository contract: business", .serialized)
struct RepositoryBusinessContractTests {
    private let fixture = ContractFixture()

    private func makeProfile(name: String = "Maria Silva") -> ProfessionalProfile {
        ProfessionalProfile(
            displayName: name, businessName: "Maria Beauty", regionCode: "BR", timeZoneID: "America/Sao_Paulo",
            currencyCode: "BRL", appLocaleID: "pt-BR", bookingLocaleIDs: ["pt-BR", "en"],
            professions: [.esthetician, .hair], clientTerm: .patient,
            vocabulary: [VocabularyTerm(text: "Protocolo 360", kind: .protocolName)], createdAt: TestClock.now
        )
    }

    @Test("There is no profile until one is saved, and saving twice keeps one", arguments: RepositoryFlavor.allCases)
    func profile(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        #expect(try await repository.profile() == nil)

        try await repository.save(makeProfile())
        fixture.clock.advance(by: 60)
        try await repository.save(makeProfile(name: "Maria S. Silva"))

        let stored = try #require(try await repository.profile())
        #expect(stored.displayName == "Maria S. Silva")
        #expect(stored.professions == [.esthetician, .hair])
        #expect(stored.clientTerm == .patient)
        #expect(stored.vocabulary.map(\.text) == ["Protocolo 360"])
        #expect(stored.bookingLocaleIDs == ["pt-BR", "en"])
        #expect(stored.updatedAt == fixture.clock.now)
    }

    @Test("Tags are listed by position and can be renamed and deleted", arguments: RepositoryFlavor.allCases)
    func tags(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let vip = Tag(id: UUID(), name: "VIP", colorToken: "rose", position: 1)
        let bridal = Tag(id: UUID(), name: "Bridal", colorToken: "peach", position: 0)
        try await repository.save(vip)
        try await repository.save(bridal)
        #expect(try await repository.tags().map(\.name) == ["Bridal", "VIP"])

        var renamed = vip
        renamed.name = "Very important"
        try await repository.save(renamed)
        #expect(try await repository.tags().map(\.name) == ["Bridal", "Very important"])

        try await repository.deleteTag(id: bridal.id)
        #expect(try await repository.tags().map(\.id) == [vip.id])
    }

    @Test("The record template round-trips with its switches", arguments: RepositoryFlavor.allCases)
    func template(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        #expect(try await repository.recordTemplate() == nil)
        let template = RecordTemplate(
            fields: [
                RecordFieldSetting(profession: .esthetician, key: "est.skin", isOn: true),
                RecordFieldSetting(profession: .esthetician, key: "custom-1", customName: "Mood", isOn: false)
            ],
            intake: [IntakeSetting(profession: .esthetician, item: .healthHistory, isOn: true)],
            updatedAt: TestClock.now
        )

        try await repository.save(template)

        let stored = try #require(try await repository.recordTemplate())
        #expect(stored.fields == template.fields)
        #expect(stored.intake == template.intake)
        #expect(stored.fields[1].customName == "Mood")
    }

    @Test("A finished setup stores the profile, services, tags and template", arguments: RepositoryFlavor.allCases)
    func saveOnboarding(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        var draft = makeDraft(professions: [.esthetician])
        draft.selectedServiceKeys = ["est.glow", "est.peel"]
        draft.selectedTagKeys = ["est.vip"]
        let result = OnboardingBuilder.build(draft: draft, catalog: makeCatalog(), now: TestClock.now)

        try await repository.saveOnboarding(result)

        #expect(try await repository.profile()?.displayName == "Maria Silva")
        #expect(try await repository.services().map(\.name) == ["Glow Facial", "Chemical Peel"])
        #expect(try await repository.tags().map(\.name) == ["VIP"])
        #expect(try await repository.recordTemplate()?.enabledKeys(for: .esthetician) == ["est.skin"])
    }

    @Test("The profile, tags and template never touch the client ledger or the client list",
          arguments: RepositoryFlavor.allCases)
    func staysApart(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        try await repository.save(makeProfile())
        try await repository.save(Tag(id: UUID(), name: "VIP", colorToken: "rose", position: 0))
        #expect(try await repository.allClients().isEmpty)
        #expect(try await repository.registrationLedger().isEmpty)
    }
}
