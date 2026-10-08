//
//  WaitlistMatcher.swift
//  BelloHub
//

import Foundation

/// Who to offer a freed time to. First come, first served among people who are still waiting, whose days include
/// the slot's day and whose service fits in the freed time.
enum WaitlistMatcher {
    static func matches(
        for slot: DateInterval, entries: [WaitlistEntry], serviceMinutes: [UUID: Int], calendar: Calendar
    ) -> [WaitlistEntry] {
        let day = calendar.startOfDay(for: slot.start)
        let slotMinutes = Int(slot.duration / 60)
        return entries
            .filter { entry in
                guard entry.status == .waiting,
                      day >= calendar.startOfDay(for: entry.dayFrom), day <= calendar.startOfDay(for: entry.dayTo)
                else { return false }
                guard let serviceID = entry.serviceID, let needed = serviceMinutes[serviceID] else { return true }
                return needed <= slotMinutes
            }
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }
}
