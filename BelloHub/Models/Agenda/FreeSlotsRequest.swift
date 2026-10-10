//
//  FreeSlotsRequest.swift
//  BelloHub
//

import Foundation

/// Everything `FreeSlotsCalculator` needs for one day.
struct FreeSlotsRequest: Sendable {
    /// `stepMinutes` meaning "match the service": the grid steps by the visit's footprint plus the buffer (D56).
    static let matchServiceStep = 0
    /// The default grid, the same on the web and in the app (docs/10).
    static let defaultStepMinutes = 15

    /// Any instant on the local day to look at, in the business time zone.
    var day: Date
    /// The visible length of the visit (service + add-ons + guests, D19).
    var durationMinutes: Int
    var now: Date
    var settings: AvailabilitySettings
    /// Visits already booked. A buffer is kept between them and a new visit.
    var appointments: [TimedInterval]
    /// Closed stretches. No buffer is added around them.
    var blocks: [DateInterval]
    /// Start times are offered on this grid from the start of each working stretch; `matchServiceStep` tiles it.
    var stepMinutes: Int
    /// The new visit's extra and processing time.
    var timing: VisitTiming
    /// "Keep my day compact": rank the starts that leave no dead gap first.
    var compact: Bool
    /// Her shortest offer with its extra time (no buffer); a gap shorter than it plus the buffer is dead.
    var shortestOfferMinutes: Int

    init(
        day: Date, durationMinutes: Int, now: Date, settings: AvailabilitySettings,
        appointments: [TimedInterval] = [], blocks: [DateInterval] = [], stepMinutes: Int = defaultStepMinutes,
        timing: VisitTiming = .noExtraTime, compact: Bool = false, shortestOfferMinutes: Int = 0
    ) {
        self.day = day
        self.durationMinutes = durationMinutes
        self.now = now
        self.settings = settings
        self.appointments = appointments
        self.blocks = blocks
        self.stepMinutes = stepMinutes
        self.timing = timing
        self.compact = compact
        self.shortestOfferMinutes = shortestOfferMinutes
    }
}
