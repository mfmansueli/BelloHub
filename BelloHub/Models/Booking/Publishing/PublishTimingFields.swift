//
//  PublishTimingFields.swift
//  BelloHub
//

import Foundation

/// A visit's extra and processing time (D56) as `publishProfile` and `publishAvailability` send it: clamped to what
/// the server accepts (0 to 60 minutes around the visit, processing inside it), and nil where there is none, so a plain
/// visit is sent exactly as before D56.
struct PublishTimingFields: Equatable, Sendable {
    var prepMinutes: Int?
    var cleanupMinutes: Int?
    var processingStartMinutes: Int?
    var processingMinutes: Int?

    init(_ timing: VisitTiming, visibleMinutes: Int) {
        let prep = min(max(timing.prepMinutes, 0), 60)
        let cleanup = min(max(timing.cleanupMinutes, 0), 60)
        prepMinutes = prep > 0 ? prep : nil
        cleanupMinutes = cleanup > 0 ? cleanup : nil
        if timing.processingMinutes > 0, timing.processingFits(visibleMinutes: visibleMinutes) {
            processingStartMinutes = timing.processingStartMinutes
            processingMinutes = timing.processingMinutes
        }
    }
}
