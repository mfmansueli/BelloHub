//
//  RecordHistoryBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RecordHistoryBuilder")
struct RecordHistoryBuilderTests {
    @Test("Records come newest first with their own corrections and their lock state")
    func itemsNewestFirst() {
        let old = makeRecord(serviceName: "Old", createdAt: TestClock.days(-10))
        let recent = makeRecord(serviceName: "Recent", createdAt: TestClock.days(0).addingTimeInterval(-3600))
        let correction = makeCorrection(recordID: old.id, createdAt: TestClock.days(-5))
        let items = RecordHistoryBuilder.items(
            records: [old, recent], corrections: [correction], now: TestClock.now
        )
        #expect(items.map(\.record.serviceName) == ["Recent", "Old"])
        #expect(items[0].isLocked == false)
        #expect(items[0].remaining != nil)
        #expect(items[1].isLocked)
        #expect(items[1].remaining == nil)
        #expect(items[1].corrections == [correction])
        #expect(items[0].corrections.isEmpty)
    }

    @Test("The time left is the lock time minus now")
    func remaining() {
        let record = makeRecord(createdAt: TestClock.now.addingTimeInterval(-20 * 3600))
        let items = RecordHistoryBuilder.items(records: [record], corrections: [], now: TestClock.now)
        #expect(items.first?.remaining == TimeInterval(4 * 3600))
    }

    @Test("No records, no items")
    func empty() {
        #expect(RecordHistoryBuilder.items(records: [], corrections: [], now: TestClock.now).isEmpty)
    }
}
