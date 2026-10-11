//
//  VisitTiming.swift
//  BelloHub
//

import Foundation

/// The shape of a visit around and inside its visible stretch (D56). Prep and clean-up are blocked before and after
/// the visit and never shown to the client, in its length or its price; processing is a stretch inside the visit,
/// `processingStartMinutes` after it begins, while she is free for another visit (colour developing, a mask setting).
/// The server mirrors it as `VisitTiming` in `functions/src/lib/freeSlots.ts`.
struct VisitTiming: Hashable, Codable, Sendable {
    var prepMinutes: Int
    var cleanupMinutes: Int
    var processingStartMinutes: Int
    var processingMinutes: Int

    static let noExtraTime = VisitTiming()
    /// The choices of the service editor for prep and clean-up (the server accepts 0 to 60).
    static let extraMinuteOptions = [0, 5, 10, 15, 20, 30, 45, 60]

    init(prepMinutes: Int = 0, cleanupMinutes: Int = 0, processingStartMinutes: Int = 0, processingMinutes: Int = 0) {
        self.prepMinutes = prepMinutes
        self.cleanupMinutes = cleanupMinutes
        self.processingStartMinutes = processingStartMinutes
        self.processingMinutes = processingMinutes
    }

    /// Nothing before, after or inside: the visit is one solid stretch.
    var isPlain: Bool { self == .noExtraTime }

    /// Minutes she is held by a visit of `visibleMinutes`, extra time included (the processing stretch still counts:
    /// it is what the shortest offer is measured in).
    func footprintMinutes(visibleMinutes: Int) -> Int {
        max(prepMinutes, 0) + visibleMinutes + max(cleanupMinutes, 0)
    }

    /// Whether the processing stretch lies inside a visit of `visibleMinutes` (the server rejects one that does not).
    func processingFits(visibleMinutes: Int) -> Bool {
        processingMinutes == 0
            || (processingStartMinutes >= 0 && processingStartMinutes + processingMinutes <= visibleMinutes)
    }
}
