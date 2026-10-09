//
//  LanguageRegionViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Exit criterion of S10: changing the region changes the previews and the web page's language set, and Save writes
/// the profile the booking page and the messages read.
@MainActor
@Suite("LanguageRegionViewModel")
struct LanguageRegionViewModelTests {
    private struct World {
        let repository: any ClientRecordRepository
        let viewModel: LanguageRegionViewModel
    }

    private func makeWorld() async throws -> World {
        let repository: any ClientRecordRepository = InMemoryClientRecordRepository()
        try await repository.save(ProfessionalProfile(
            displayName: "Maria Silva", regionCode: "BR", timeZoneID: "America/Sao_Paulo", currencyCode: "BRL",
            appLocaleID: "pt-BR", bookingLocaleIDs: ["pt-BR", "en"], createdAt: TestClock.now
        ))
        let profile = ProfileService(repository: repository)
        await profile.load()
        let viewModel = LanguageRegionViewModel(
            profile: profile, bookingSetup: BookingSetupService(repository: repository),
            regions: try RegionCatalog.loadBundled(), now: { TestClock.now }
        )
        return World(repository: repository, viewModel: viewModel)
    }

    private func row(_ key: String, in preview: LocalePreview) -> String? {
        preview.rows.first { $0.key == key }?.value
    }

    @Test("Choosing Germany changes the currency, date, week start, phone and privacy rows and the message language")
    func regionChangesPreviews() async throws {
        let viewModel = try await makeWorld().viewModel
        let before = viewModel.preview
        #expect(row("languageRegion.sets.privacyLaw", in: before) == "LGPD")
        #expect(row("languageRegion.sets.currency", in: before)?.contains("R$") == true)
        #expect(!viewModel.canSave)

        viewModel.choose(try #require(viewModel.presets.first { $0.code == "DE" }))
        let after = viewModel.preview

        #expect(viewModel.draft.localization == .de)
        #expect(row("languageRegion.sets.privacyLaw", in: after)?.hasPrefix("GDPR") == true)
        #expect(row("languageRegion.sets.currency", in: after)?.contains("€") == true)
        #expect(row("languageRegion.sets.weekStart", in: after) == "Montag")
        #expect(row("languageRegion.sets.phone", in: after)?.hasPrefix("+49") == true)
        #expect(after.messages != before.messages, "the quick replies render in German now")
        #expect(after.messages.allSatisfy { $0.contains("Ana") }, "the sample client is in every message")
        #expect(viewModel.isOnPage(.de) && !viewModel.isOnPage(.ptBR))
        #expect(viewModel.canSave)
    }

    @Test("Week start and clock overrides change the preview rows and survive Save")
    func weekAndClock() async throws {
        let world = try await makeWorld()
        let viewModel = world.viewModel

        viewModel.setFirstWeekday(1)
        viewModel.setUse24Hour(false)
        #expect(row("languageRegion.sets.weekStart", in: viewModel.preview) == "domingo")
        #expect(row("languageRegion.sets.time", in: viewModel.preview)?.contains("AM") == true
            || row("languageRegion.sets.time", in: viewModel.preview)?.contains("PM") == true)

        await viewModel.saveAsync()

        let stored = try #require(try await world.repository.profile())
        #expect(stored.firstWeekday == 1)
        #expect(stored.use24Hour == false)
        #expect(viewModel.saved)
    }

    @Test("Page languages: the business one cannot leave; Save writes the set the web page offers")
    func pageLanguages() async throws {
        let world = try await makeWorld()
        let viewModel = world.viewModel

        viewModel.togglePageLanguage(.ptBR)
        #expect(viewModel.isOnPage(.ptBR), "the business language stays")
        viewModel.togglePageLanguage(.es)
        viewModel.togglePageLanguage(.en)
        #expect(viewModel.draft.bookingLocaleIDs == ["pt-BR", "es"])

        await viewModel.saveAsync()

        #expect(try await world.repository.profile()?.bookingLocaleIDs == ["pt-BR", "es"])
    }

    @Test("Switching the language to Arabic flips the previews to right-to-left text")
    func arabicPreview() async throws {
        let viewModel = try await makeWorld().viewModel

        viewModel.choose(.ar)

        #expect(viewModel.draft.localization.isRightToLeft)
        #expect(viewModel.preview.messages.first?.unicodeScalars.contains { $0.value >= 0x0600 && $0.value <= 0x06FF }
            == true)
        #expect(viewModel.draft.bookingLocaleIDs.first == "ar")
    }
}
