//
//  PatchTestStatus.swift
//  BelloHub
//

import Foundation

/// Where a client stands on the patch test the visit's service asks for (3.2, 3.3). It informs and never blocks (D16).
enum PatchTestStatus: Equatable, Sendable {
    /// The service does not ask for one.
    case notRequired
    /// The service asks for one and none is on record.
    case missing
    /// The latest one is still being watched (the skin is observed for 24 to 72 hours).
    case stillObserving(until: Date)
    /// The latest one had no reaction.
    case clear(testedAt: Date)
    /// The latest one had a reaction: look before treating.
    case reaction(testedAt: Date, result: PatchTestResult)

    static func make(service: Service?, patchTests: [PatchTest], now: Date) -> PatchTestStatus {
        guard let service, service.requiresPatchTest else { return .notRequired }
        guard let latest = patchTests.max(by: { $0.testedAt < $1.testedAt }) else { return .missing }
        if latest.result.needsAttention { return .reaction(testedAt: latest.testedAt, result: latest.result) }
        let observedUntil = latest.testedAt.addingTimeInterval(TimeInterval(latest.observedHours * 3600))
        return observedUntil > now ? .stillObserving(until: observedUntil) : .clear(testedAt: latest.testedAt)
    }

    /// Worth a warning chip on the detail.
    var needsAttention: Bool {
        switch self {
        case .missing, .reaction: true
        case .notRequired, .stillObserving, .clear: false
        }
    }
}
