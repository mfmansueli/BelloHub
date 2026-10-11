//
//  AvailabilitySettings+Zone.swift
//  BelloHub
//

import Foundation

extension AvailabilitySettings {
    /// The same hours, breaks and days off read in `timeZone`: every wall-clock time and every calendar date stays
    /// what she chose, only the zone they are read in changes.
    ///
    /// Her hours are wall-clock times ("09:00 to 18:00") and her days off are dates; the zone stored with them is only
    /// the zone they were saved in, which can be the phone's (before her profile was read), while the calendar and the
    /// server read days in her business zone. A screen that lays out days in the business zone must compute free times
    /// in that same zone, or a day chosen as Tuesday is cut from Monday's hours whenever the two zones differ
    /// (fix-reschedule-day). So every screen reads them through this, with the zone of its own `CalendarDays`.
    func inTimeZone(_ timeZone: TimeZone) -> AvailabilitySettings {
        guard timeZoneID != timeZone.identifier else { return self }
        var saved = Calendar(identifier: .gregorian)
        saved.timeZone = self.timeZone
        var target = Calendar(identifier: .gregorian)
        target.timeZone = timeZone
        // A day off is stored as the start of its day in the zone it was saved in; the same date starts elsewhere.
        func sameDate(_ date: Date) -> Date {
            target.date(from: saved.dateComponents([.year, .month, .day], from: date)) ?? date
        }
        var read = self
        read.timeZoneID = timeZone.identifier
        read.daysOff = daysOff.map {
            DayOff(id: $0.id, startDate: sameDate($0.startDate), endDate: sameDate($0.endDate), kind: $0.kind)
        }
        return read
    }
}
