//
//  LanguageRegionRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("LanguageRegionRules")
struct LanguageRegionRulesTests {
    private let catalog = (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: [])

    private var brazil: LanguageRegionDraft {
        LanguageRegionDraft(
            regionCode: "BR", localization: .ptBR, currencyCode: "BRL", firstWeekday: 2, use24Hour: false,
            bookingLocaleIDs: ["pt-BR", "en"]
        )
    }

    @Test("Choosing a region takes its language, currency and page languages and drops the week overrides")
    func choosingRegion() throws {
        let germany = try #require(catalog.preset(for: "DE"))

        let draft = LanguageRegionRules.choosing(germany, in: brazil)

        #expect(draft.regionCode == "DE")
        #expect(draft.localization == .de)
        #expect(draft.currencyCode == "EUR")
        #expect(draft.firstWeekday == nil)
        #expect(draft.use24Hour == nil)
        #expect(draft.bookingLocaleIDs.first == "de", "the business language leads the page")
        #expect(Set(draft.bookingLocaleIDs) == Set(["de"] + germany.localizations))
    }

    @Test("Changing the language keeps it on the page first and keeps the other page languages")
    func choosingLanguage() {
        let draft = LanguageRegionRules.choosing(.es, in: brazil)

        #expect(draft.localization == .es)
        #expect(draft.bookingLocaleIDs == ["es", "pt-BR", "en"])
        #expect(draft.regionCode == "BR", "the region does not move")
    }

    @Test("Page languages toggle on and off, except the business one; unknown ids are dropped")
    func toggling() {
        var draft = LanguageRegionRules.toggling(.fr, in: brazil)
        #expect(draft.bookingLocaleIDs == ["pt-BR", "en", "fr"])
        draft = LanguageRegionRules.toggling(.fr, in: draft)
        #expect(draft.bookingLocaleIDs == ["pt-BR", "en"])
        #expect(LanguageRegionRules.toggling(.ptBR, in: brazil) == brazil)
        #expect(LanguageRegionRules.pageLocales(["xx", "en", "en"], business: .de) == ["de", "en"])
    }

    @Test("The effective week start and clock are hers when set, the region's otherwise")
    func effectiveWeek() {
        #expect(LanguageRegionRules.effectiveWeekConfig(brazil) == WeekConfig(firstWeekday: 2, use24Hour: false))
        let regionDefault = LanguageRegionDraft(
            regionCode: "DE", localization: .de, currencyCode: "EUR", bookingLocaleIDs: ["de"]
        )
        let config = LanguageRegionRules.effectiveWeekConfig(regionDefault)
        #expect(config == WeekConfig.defaults(forRegion: "DE", languageCode: "de"))
        #expect(config.firstWeekday == 2)
        #expect(config.use24Hour)
    }

    @Test("Currency options list hers first, then every preset currency once")
    func currencies() throws {
        let presets = catalog.presetsForPicker
        let options = LanguageRegionRules.currencyOptions(current: "CHF", presets: presets)
        #expect(options.first == "CHF")
        #expect(options.contains("EUR") && options.contains("BRL") && options.contains("USD"))
        #expect(Set(options).count == options.count, "no repeats")
    }

    @Test("Changes compare the draft with the stored profile; applying writes only the region fields")
    func changesAndApply() {
        let profile = ProfessionalProfile(
            displayName: "Maria", businessName: "Glow", regionCode: "BR", timeZoneID: "America/Sao_Paulo",
            currencyCode: "BRL", appLocaleID: "pt-BR", bookingLocaleIDs: ["pt-BR", "en"], firstWeekday: 2,
            use24Hour: false, createdAt: TestClock.now
        )
        #expect(!LanguageRegionRules.hasChanges(brazil, profile: profile))
        var draft = brazil
        draft.currencyCode = "USD"
        #expect(LanguageRegionRules.hasChanges(draft, profile: profile))
        let applied = draft.applied(to: profile)
        #expect(applied.currencyCode == "USD")
        #expect(applied.displayName == "Maria" && applied.businessName == "Glow")
    }
}
