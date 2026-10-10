//
//  PayloadInstantTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PayloadInstant")
struct PayloadInstantTests {
    private let expected = Date(timeIntervalSince1970: 1_791_468_201) // 2026-10-08T14:03:21Z

    @Test("Reads the browser's toISOString() form, with milliseconds")
    func readsMilliseconds() {
        #expect(PayloadInstant.parse("2026-10-08T14:03:21.000Z") == expected)
        #expect(PayloadInstant.parse("2026-10-08T14:03:21.250Z") == expected.addingTimeInterval(0.25))
    }

    @Test("Reads whole seconds and offsets")
    func readsWholeSeconds() {
        #expect(PayloadInstant.parse("2026-10-08T14:03:21Z") == expected)
        #expect(PayloadInstant.parse("2026-10-08T11:03:21-03:00") == expected)
    }

    @Test("Anything that is not an ISO-8601 instant is nil")
    func refusesOtherText() {
        #expect(PayloadInstant.parse("") == nil)
        #expect(PayloadInstant.parse("yesterday") == nil)
        #expect(PayloadInstant.parse("2026-10-08") == nil)
    }
}
