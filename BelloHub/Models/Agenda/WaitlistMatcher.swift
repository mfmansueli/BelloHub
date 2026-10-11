//
//  WaitlistMatcher.swift
//  BelloHub
//

import Foundation

/// Who to offer a freed time to. First come, first served among people who are still waiting, whose days include
/// the slot's day and whose service has a free start that uses the freed time (D56: worked out by
/// `FreeSlotsCalculator`, so extra time, processing time and the buffer all count). Mirrors `matchesWaitlist` in
/// `functions/src/lib/waitlistMatch.ts`.
enum WaitlistMatcher {
    /// `serviceFits`: for each service people wait for, whether it now has a free start that uses the freed time. A
    /// service missing from it (removed, or none named) does not stop a match.
    static func matches(
        for slot: DateInterval, entries: [WaitlistEntry], serviceFits: [UUID: Bool], calendar: Calendar
    ) -> [WaitlistEntry] {
        let day = calendar.startOfDay(for: slot.start)
        return entries
            .filter { entry in
                guard entry.status == .waiting,
                      day >= calendar.startOfDay(for: entry.dayFrom), day <= calendar.startOfDay(for: entry.dayTo)
                else { return false }
                guard let serviceID = entry.serviceID else { return true }
                return serviceFits[serviceID] ?? true
            }
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }

    /// Whether one of `starts` (the free starts of a service of `minutes` with `timing`, the freed visit no longer
    /// holding time) uses some of the freed stretch.
    static func usesFreedTime(_ freed: DateInterval, starts: [Date], minutes: Int, timing: VisitTiming) -> Bool {
        starts.contains { start in
            let from = start.addingTimeInterval(-TimeInterval(timing.prepMinutes * 60))
            let to = start.addingTimeInterval(TimeInterval((minutes + timing.cleanupMinutes) * 60))
            return from < freed.end && to > freed.start
        }
    }
}
