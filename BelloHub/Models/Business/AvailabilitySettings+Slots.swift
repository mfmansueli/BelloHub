//
//  AvailabilitySettings+Slots.swift
//  BelloHub
//

import Foundation

/// How her free times are offered (D56): the slot interval and "Keep my day compact", with the defaults of a setting
/// saved before they existed.
extension AvailabilitySettings {
    /// The slot intervals Booking settings offers, "match the service" last.
    static let slotStepOptions = [10, 15, 20, 30, 60, FreeSlotsRequest.matchServiceStep]

    /// The choices of the slot interval menu: the standard ones, plus `current` when it is not one of them (in order,
    /// "match the service" always last).
    static func slotStepChoices(including current: Int) -> [Int] {
        guard !slotStepOptions.contains(current), current > 0 else { return slotStepOptions }
        return (slotStepOptions.filter { $0 > 0 } + [current]).sorted() + [FreeSlotsRequest.matchServiceStep]
    }

    /// The grid of start times in minutes, or `FreeSlotsRequest.matchServiceStep`.
    var effectiveSlotStep: Int { slotStepMinutes ?? FreeSlotsRequest.defaultStepMinutes }

    /// Whether the times that leave no dead gap are shown first.
    var keepsDayCompact: Bool { compactDay ?? true }

    /// Her shortest offer with its extra time, from the services she offers: what a gap must hold not to be dead.
    /// 0 when she offers none (then nothing is ranked).
    static func shortestOfferMinutes(of services: [Service]) -> Int {
        services.filter(\.isActive)
            .map { $0.visitTiming.footprintMinutes(visibleMinutes: $0.durationMinutes) }
            .min() ?? 0
    }
}
