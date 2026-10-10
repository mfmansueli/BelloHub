//
//  TimedInterval.swift
//  BelloHub
//

import Foundation

/// A visit that already holds time: its visible stretch and its shape (D56), for `FreeSlotsCalculator`.
struct TimedInterval: Hashable, Sendable {
    var interval: DateInterval
    var timing: VisitTiming

    init(_ interval: DateInterval, timing: VisitTiming = .noExtraTime) {
        self.interval = interval
        self.timing = timing
    }
}
