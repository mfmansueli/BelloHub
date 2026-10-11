//
//  ProfessionAgendaDefaults.swift
//  BelloHub
//

import Foundation

/// The agenda settings that suit a profession's routine (routine item 10): time between clients, the slot interval
/// and "Keep my day compact". Offered on Booking page as "Suggested for <profession>" with a "Use these" button; it
/// never changes anything by itself. Values are judgement from how each trade books (short barber visits on a 15-minute
/// grid with little reset time; lash and massage rooms need a fuller reset and book on the half hour; a tattoo station
/// needs the longest clean-up), not data from the catalogs, which only know services and their minutes.
struct ProfessionAgendaDefaults: Equatable, Sendable {
    let bufferMinutes: Int
    let slotStepMinutes: Int
    let compactDay: Bool

    static func defaults(for profession: ProfessionID) -> ProfessionAgendaDefaults {
        switch profession {
        case .esthetician: ProfessionAgendaDefaults(bufferMinutes: 15, slotStepMinutes: 15, compactDay: true)
        case .hair: ProfessionAgendaDefaults(bufferMinutes: 10, slotStepMinutes: 15, compactDay: true)
        case .lash: ProfessionAgendaDefaults(bufferMinutes: 15, slotStepMinutes: 30, compactDay: true)
        case .nail: ProfessionAgendaDefaults(bufferMinutes: 10, slotStepMinutes: 15, compactDay: true)
        case .makeup: ProfessionAgendaDefaults(bufferMinutes: 15, slotStepMinutes: 30, compactDay: true)
        case .tattoo: ProfessionAgendaDefaults(bufferMinutes: 30, slotStepMinutes: 30, compactDay: true)
        case .barber: ProfessionAgendaDefaults(bufferMinutes: 5, slotStepMinutes: 15, compactDay: true)
        case .massage: ProfessionAgendaDefaults(bufferMinutes: 15, slotStepMinutes: 30, compactDay: true)
        case .other:
            ProfessionAgendaDefaults(
                bufferMinutes: AvailabilitySettings.defaultBufferMinutes,
                slotStepMinutes: FreeSlotsRequest.defaultStepMinutes, compactDay: true
            )
        }
    }

    /// The suggestion for her first profession, or nil when she has none.
    static func suggestion(for professions: [ProfessionID]) -> (profession: ProfessionID, defaults: Self)? {
        guard let first = professions.first else { return nil }
        return (first, defaults(for: first))
    }

    /// Whether her settings already are these values.
    func matches(_ settings: AvailabilitySettings) -> Bool {
        settings.bufferMinutes == bufferMinutes && settings.effectiveSlotStep == slotStepMinutes
            && settings.keepsDayCompact == compactDay
    }

    /// Her settings with these three values; hours, breaks, notice and window stay hers.
    func applied(to settings: AvailabilitySettings) -> AvailabilitySettings {
        var updated = settings
        updated.bufferMinutes = bufferMinutes
        updated.slotStepMinutes = slotStepMinutes
        updated.compactDay = compactDay
        return updated
    }
}
