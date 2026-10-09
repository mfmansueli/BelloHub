//
//  Formatters+Record.swift
//  BelloHub
//

import Foundation

extension Formatters {
    /// "3 hr, 20 min" for the time left before a record locks.
    func remaining(_ interval: TimeInterval) -> String {
        let minutes = max(1, Int((interval / 60).rounded(.up)))
        let duration = Duration.seconds(minutes * 60)
        return duration.formatted(
            .units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale)
        )
    }
}
