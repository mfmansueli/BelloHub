//
//  FreeSlotsCalculator+Day.swift
//  BelloHub
//

import Foundation

/// The candidates of one working stretch and their check (D56), mirroring the loop of `planSlots` in
/// `functions/src/lib/freeSlots.ts`.
extension FreeSlotsCalculator {
    /// A day's fixed inputs, worked out once for all its working stretches.
    struct Day {
        let buffer: TimeInterval
        let earliest: Date
        let duration: TimeInterval
        let prep: TimeInterval
        let cleanup: TimeInterval
        let step: TimeInterval
        let matchesService: Bool
        let timing: VisitTiming
        let closed: [Segment]
        let visits: [Segment]
        let shortest: TimeInterval
        /// Whether the compact-day ranking applies (on, and her shortest offer is known).
        let isRanked: Bool

        init(request: FreeSlotsRequest, breaks: [DateInterval]) {
            buffer = minutes(request.settings.bufferMinutes)
            earliest = request.now.addingTimeInterval(TimeInterval(request.settings.minNoticeHours * 3600))
            duration = minutes(request.durationMinutes)
            timing = request.timing
            prep = minutes(max(timing.prepMinutes, 0))
            cleanup = minutes(max(timing.cleanupMinutes, 0))
            matchesService = request.stepMinutes <= 0
            let footprint = prep + duration + cleanup
            step = max(matchesService ? footprint + buffer : minutes(request.stepMinutes), minutes(1))
            closed = (breaks + request.blocks).map {
                Segment(start: $0.start, end: $0.end, bufferedStart: false, bufferedEnd: false)
            }
            visits = request.appointments.flatMap {
                Segment.of(start: $0.interval.start, end: $0.interval.end, timing: $0.timing)
            }
            shortest = minutes(max(request.shortestOfferMinutes, 0))
            isRanked = request.compact && shortest > 0
        }

        private var obstacles: [Segment] { visits + closed }

        /// The free starts of one working stretch, in time order, with the gap each sits in.
        func placements(in window: DateInterval) -> [Placement] {
            candidates(in: window).sorted().compactMap { placement(at: $0, in: window) }
        }

        /// The grid ("match the service" tiles the stretch once the first prep is done) plus the anchored starts.
        private func candidates(in window: DateInterval) -> Set<Date> {
            var found: Set<Date> = []
            var start = matchesService ? window.start.addingTimeInterval(prep) : window.start
            while start.addingTimeInterval(duration) <= window.end {
                found.insert(start)
                start = start.addingTimeInterval(step)
            }
            found.insert(roundUp(window.start.addingTimeInterval(prep)))
            found.insert(roundDown(window.end.addingTimeInterval(-cleanup - duration)))
            for segment in obstacles {
                found.insert(roundUp(segment.end.addingTimeInterval((segment.bufferedEnd ? buffer : 0) + prep)))
                found.insert(roundDown(segment.start.addingTimeInterval(
                    -(segment.bufferedStart ? buffer : 0) - cleanup - duration
                )))
            }
            return found
        }

        private func placement(at start: Date, in window: DateInterval) -> Placement? {
            let outer = Segment(start: start.addingTimeInterval(-prep),
                                end: start.addingTimeInterval(duration + cleanup),
                                bufferedStart: true, bufferedEnd: true)
            guard start >= earliest, outer.start >= window.start, outer.end <= window.end,
                  !closed.contains(where: { outer.conflicts(with: $0, buffer: 0) }) else { return nil }
            let own = Segment.of(start: start, end: start.addingTimeInterval(duration), timing: timing)
            let clashes = own.contains { mine in visits.contains { mine.conflicts(with: $0, buffer: buffer) } }
            return clashes ? nil : gapPlacement(start: start, outer: outer, window: window)
        }

        /// The gap a free start sits in and the dead time it leaves on each side.
        private func gapPlacement(start: Date, outer: Segment, window: DateInterval) -> Placement {
            // The minimum notice is not an edge: time that has passed is lost whichever start she gets.
            var previous = window.start
            var next = window.end
            for segment in obstacles {
                if segment.end <= outer.start {
                    previous = max(previous, segment.end.addingTimeInterval(segment.bufferedEnd ? buffer : 0))
                }
                if segment.start >= outer.end {
                    next = min(next, segment.start.addingTimeInterval(segment.bufferedStart ? -buffer : 0))
                }
            }
            let needed = shortest + buffer
            var dead: TimeInterval = 0
            var count = 0
            for slack in [outer.start.timeIntervalSince(previous), next.timeIntervalSince(outer.end)]
            where slack > 0 && slack < needed {
                dead += slack
                count += 1
            }
            return Placement(start: start, gap: Gap(previous: previous, next: next), deadSeconds: dead,
                             deadCount: count)
        }
    }
}
