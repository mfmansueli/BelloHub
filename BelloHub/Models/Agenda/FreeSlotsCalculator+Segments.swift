//
//  FreeSlotsCalculator+Segments.swift
//  BelloHub
//

import Foundation

/// The stretches that hold her, and the compact-day ranking of D56 (mirrors `segmentsOf`, `conflicts` and
/// `compactStarts` in `functions/src/lib/freeSlots.ts`).
extension FreeSlotsCalculator {
    /// A stretch that holds her, with whether the buffer is kept at each edge: not at the edge of a processing
    /// stretch, a break or a block.
    struct Segment: Hashable, Sendable {
        var start: Date
        var end: Date
        var bufferedStart: Bool
        var bufferedEnd: Bool

        /// The stretches a visit holds her: prep + visit + clean-up, split around its processing stretch.
        static func of(start: Date, end: Date, timing: VisitTiming) -> [Segment] {
            let outerStart = start.addingTimeInterval(-minutes(max(timing.prepMinutes, 0)))
            let outerEnd = end.addingTimeInterval(minutes(max(timing.cleanupMinutes, 0)))
            let gapStart = start.addingTimeInterval(minutes(timing.processingStartMinutes))
            let gapEnd = gapStart.addingTimeInterval(minutes(timing.processingMinutes))
            let hasGap = timing.processingMinutes > 0 && timing.processingStartMinutes >= 0 && gapEnd <= end
            let segments = hasGap
                ? [Segment(start: outerStart, end: gapStart, bufferedStart: true, bufferedEnd: false),
                   Segment(start: gapEnd, end: outerEnd, bufferedStart: false, bufferedEnd: true)]
                : [Segment(start: outerStart, end: outerEnd, bufferedStart: true, bufferedEnd: true)]
            return segments.filter { $0.end > $0.start }
        }

        /// Two stretches clash when the gap between them is smaller than the buffer owed at the edges that meet.
        func conflicts(with other: Segment, buffer: TimeInterval) -> Bool {
            let afterOther = other.bufferedEnd && bufferedStart ? buffer : 0
            let afterSelf = bufferedEnd && other.bufferedStart ? buffer : 0
            return start < other.end.addingTimeInterval(afterOther) && other.start < end.addingTimeInterval(afterSelf)
        }
    }

    /// The free stretch a start sits in: from the nearest thing before it to the nearest thing after it.
    struct Gap: Hashable, Sendable {
        var previous: Date
        var next: Date
    }

    /// One free start and the dead time it leaves on each side of it.
    struct Placement: Hashable, Sendable {
        var start: Date
        var gap: Gap
        var deadSeconds: TimeInterval
        var deadCount: Int

        func isBetter(than other: Placement) -> Bool {
            deadSeconds < other.deadSeconds || (deadSeconds == other.deadSeconds && deadCount < other.deadCount)
        }
    }

    /// Per gap: the starts that leave no dead time, or else the least dead time and then the fewest dead fragments.
    static func compactStarts(_ placements: [Placement]) -> [Date] {
        var best: [Gap: Placement] = [:]
        for item in placements {
            if let current = best[item.gap], !item.isBetter(than: current) { continue }
            best[item.gap] = item
        }
        return placements.filter { item in
            guard let winner = best[item.gap] else { return false }
            return item.deadSeconds == winner.deadSeconds && item.deadCount == winner.deadCount
        }.map(\.start)
    }

    static func minutes(_ value: Int) -> TimeInterval {
        TimeInterval(value * 60)
    }

    static func roundUp(_ date: Date) -> Date {
        let size = minutes(anchorRoundingMinutes)
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / size).rounded(.up) * size)
    }

    static func roundDown(_ date: Date) -> Date {
        let size = minutes(anchorRoundingMinutes)
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / size).rounded(.down) * size)
    }
}
