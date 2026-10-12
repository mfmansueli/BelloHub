//
//  VisitDateLabel.swift
//  BelloHub
//

import Foundation

/// The words for a visit's day (`RecordVisitDate`): the day itself, or, for an old record with no visit day, when it
/// was written and that the day was not noted. One owner, so the card, the details and "Before you start" agree.
enum VisitDateLabel {
    static func text(_ visitDate: RecordVisitDate, formatters: Formatters, now: Date, locale: Locale) -> String {
        let day = formatters.recentDate(visitDate.date, now: now)
        guard !visitDate.isVisitDay else { return day }
        return LocalizedStringResource(
            "clientRecord.visit.writtenOn", defaultValue: "Written \(day) · visit day not noted"
        ).resolved(in: locale)
    }
}
