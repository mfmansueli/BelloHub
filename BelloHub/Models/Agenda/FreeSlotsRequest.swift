//
//  FreeSlotsRequest.swift
//  BelloHub
//

import Foundation

/// Everything `FreeSlotsCalculator` needs for one day.
struct FreeSlotsRequest: Sendable {
    /// Any instant on the local day to look at, in the business time zone.
    var day: Date
    var durationMinutes: Int
    var now: Date
    var settings: AvailabilitySettings
    /// Visits already booked. A buffer is kept between them and a new visit.
    var appointments: [DateInterval]
    /// Closed stretches. No buffer is added around them.
    var blocks: [DateInterval]
    /// Start times are offered on this grid from the start of each working stretch.
    var stepMinutes: Int

    init(
        day: Date, durationMinutes: Int, now: Date, settings: AvailabilitySettings,
        appointments: [DateInterval] = [], blocks: [DateInterval] = [], stepMinutes: Int = 15
    ) {
        self.day = day
        self.durationMinutes = durationMinutes
        self.now = now
        self.settings = settings
        self.appointments = appointments
        self.blocks = blocks
        self.stepMinutes = stepMinutes
    }
}
