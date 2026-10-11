//
//  ProfessionAgendaDefaultsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ProfessionAgendaDefaults")
struct ProfessionAgendaDefaultsTests {
    @Test("Every profession suggests values her menus offer", arguments: ProfessionID.allCases)
    func valuesAreOffered(profession: ProfessionID) {
        let defaults = ProfessionAgendaDefaults.defaults(for: profession)

        #expect(AvailabilityEditor.bufferOptions.contains(defaults.bufferMinutes))
        #expect(AvailabilitySettings.slotStepOptions.contains(defaults.slotStepMinutes))
    }

    @Test("Applying changes only the three values; hours, notice and window stay hers")
    func applied() {
        let settings = makeAvailability(bufferMinutes: 45, minNoticeHours: 12, maxDaysAhead: 90)
        let updated = ProfessionAgendaDefaults.defaults(for: .lash).applied(to: settings)

        #expect(updated.bufferMinutes == 15 && updated.slotStepMinutes == 30 && updated.compactDay == true)
        #expect(updated.weekly == settings.weekly && updated.breaks == settings.breaks)
        #expect(updated.minNoticeHours == 12 && updated.maxDaysAhead == 90)
        #expect(ProfessionAgendaDefaults.defaults(for: .lash).matches(updated))
        #expect(!ProfessionAgendaDefaults.defaults(for: .lash).matches(settings))
    }

    @Test("A setting saved before D56 (no interval, no compact flag) is read with its defaults")
    func legacySettings() {
        let legacy = makeAvailability(bufferMinutes: 15)

        #expect(ProfessionAgendaDefaults.defaults(for: .esthetician).matches(legacy))
    }

    @Test("The suggestion is for her first profession; none without a profession")
    func suggestion() {
        #expect(ProfessionAgendaDefaults.suggestion(for: [.barber, .hair])?.profession == .barber)
        #expect(ProfessionAgendaDefaults.suggestion(for: []) == nil)
    }
}
