//
//  TreatmentFlowViewModel+NextSession.swift
//  BelloHub
//

import Foundation

/// The next visit: a suggested interval and date on the form (written into the record as a note), and "Book return"
/// in the confirmation, which opens the new-appointment sheet. Nothing here sends anything to the client.
extension TreatmentFlowViewModel {
    var weekChoices: [Int] { NextSessionRules.choices(including: NextSessionRules.suggestedWeeks(
        serviceFollowUpWeeks: service?.followUpWeeks
    )) }

    /// The interval the service asks for, or the general default when it has none.
    var defaultWeeks: Int { NextSessionRules.suggestedWeeks(serviceFollowUpWeeks: service?.followUpWeeks) }

    var hasServiceDefault: Bool { (service?.followUpWeeks ?? 0) > 0 }

    func suggestedDate(calendar: Calendar) -> Date {
        NextSessionRules.date(afterVisit: visitDate, weeks: nextWeeks, now: now(), calendar: calendar)
    }

    /// Sets the interval of the next visit ("4 wk"), written into the record as its next-session note.
    func setNextWeeks(_ weeks: Int) {
        nextWeeks = weeks
        set(formatters.weeks(weeks), for: TreatmentFormField.nextSessionKey)
    }

    /// The next-session note on the form, if she set one.
    var nextSessionNote: String {
        draft.value(for: TreatmentFormField.nextSessionKey)
    }
}
