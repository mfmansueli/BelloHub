//
//  BookingSettingsAgendaHelpTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The parts of Booking page added by routine item 10: the suggestion for her profession, "More options" opening by
/// itself, and the preview fed with her services.
@Suite("BookingSettingsViewModel agenda help")
@MainActor
struct BookingSettingsAgendaHelpTests {
    private func makeProfile(professions: [ProfessionID]) -> ProfessionalProfile {
        ProfessionalProfile(
            displayName: "Maria Silva", regionCode: "BR", timeZoneID: "America/Sao_Paulo", currencyCode: "BRL",
            appLocaleID: "en", professions: professions, createdAt: TestClock.now
        )
    }

    private func makeModel(
        professions: [ProfessionID] = [.hair], services: [Service] = []
    ) async throws -> (BookingSettingsViewModel, FakeBookingSetupRepository) {
        let repository = FakeBookingSetupRepository()
        let agenda = FakeAgendaRepository()
        for service in services { try await agenda.save(service) }
        let service = BookingSetupService(repository: repository, now: { TestClock.now })
        let model = BookingSettingsViewModel(
            service: service, profile: makeProfile(professions: professions), services: agenda,
            now: { TestClock.now }
        )
        await model.loadAsync()
        return (model, repository)
    }

    @Test("Her profession's values are suggested while hers differ, and 'Use these' saves them and keeps her hours")
    func suggestion() async throws {
        let (model, repository) = try await makeModel(professions: [.hair])
        let hoursBefore = model.availability.weekly

        let suggestion = try #require(model.professionSuggestion)
        #expect(suggestion.profession == .hair && suggestion.defaults.bufferMinutes == 10)
        #expect(model.professionName == "Hair stylist")

        await model.useSuggestedDefaults()

        #expect(model.professionSuggestion == nil, "the card goes away once her values match")
        let stored = try #require(try await repository.availability())
        #expect(stored.bufferMinutes == 10 && stored.effectiveSlotStep == 15 && stored.keepsDayCompact)
        #expect(stored.weekly == hoursBefore)
    }

    @Test("No profession, no suggestion")
    func noProfession() async throws {
        let (model, _) = try await makeModel(professions: [])
        #expect(model.professionSuggestion == nil && model.professionName == nil)
    }

    @Test("'More options' opens by itself only when the start times or the compact day were changed")
    func advancedChanges() async throws {
        let (model, _) = try await makeModel()
        #expect(!model.hasAdvancedChanges)

        await model.setSlotStep(30)
        #expect(model.hasAdvancedChanges)

        await model.setSlotStep(15)
        await model.setCompactDay(false)
        #expect(model.hasAdvancedChanges)
    }

    @Test("The preview uses her services: the longest by default, the one she picks after")
    func previewUsesServices() async throws {
        let haircut = Service(name: "Haircut", durationMinutes: 30)
        let color = Service(name: "Color", durationMinutes: 120, position: 1)
        let (model, _) = try await makeModel(services: [haircut, color])

        #expect(model.previewableServices.map(\.name) == ["Haircut", "Color"])
        #expect(model.slotPreview?.serviceName == "Color")

        model.previewServiceID = haircut.id
        #expect(model.slotPreview?.serviceName == "Haircut")
    }

    @Test("A change to a rule changes the preview at once, with no server call")
    func previewFollowsRules() async throws {
        let (model, _) = try await makeModel()
        let before = try #require(model.slotPreview)

        await model.setSlotStep(60)

        let after = try #require(model.slotPreview)
        #expect((after.shownFirst + after.alsoBookable).count < (before.shownFirst + before.alsoBookable).count)
    }
}
