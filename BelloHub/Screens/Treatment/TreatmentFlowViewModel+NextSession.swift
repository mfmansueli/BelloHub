//
//  TreatmentFlowViewModel+NextSession.swift
//  BelloHub
//

import Foundation

/// The next-session step (5.9): a suggested interval and date, a note in the record, and a way into the new-appointment
/// sheet. Reminders to the client are not part of this front end (they need the S6/S8 services), so nothing here
/// sends anything.
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

    /// Writes the interval into the record ("4 wk") so the history shows it. Allowed because the record is still
    /// inside its 24-hour window; if the vault refuses, the step says so and she can book anyway.
    @discardableResult
    func saveSuggestion(formatters: Formatters) async -> Bool {
        guard let repository, var record = savedRecord else { return true }
        // A locked record changes only through a correction (RecordLockPolicy).
        guard isRecordEditable else { return false }
        record.nextSessionSuggestion = formatters.weeks(nextWeeks)
        do {
            try await repository.save(record)
            savedRecord = record
            suggestionSaved = true
            return true
        } catch {
            failure = .save
            return false
        }
    }
}
