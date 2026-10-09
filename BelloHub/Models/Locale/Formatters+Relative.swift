//
//  Formatters+Relative.swift
//  BelloHub
//

import Foundation

extension Formatters {
    /// "28 days ago", in the reader's language (the system's own plural and wording rules, so no catalog key is
    /// needed). `days` counts whole days back from today; one day back reads "yesterday" where the language has the
    /// word.
    func daysAgo(_ days: Int) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(from: DateComponents(day: -max(days, 0)))
    }
}
