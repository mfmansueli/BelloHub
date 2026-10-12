//
//  RecordTrailBuilderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RecordTrailBuilder")
struct RecordTrailBuilderTests {
    private let created = TestClock.date("2026-08-30 17:42")

    private func kinds(_ entries: [RecordTrailEntry]) -> [String] {
        entries.map { entry in
            switch entry.kind {
            case .created: "created"
            case .finalized: "finalized"
            case .locked: "locked"
            case .correction: "correction"
            }
        }
    }

    @Test("A new record has only its creation")
    func newRecord() {
        let record = makeRecord(createdAt: created)
        let entries = RecordTrailBuilder.entries(for: record, corrections: [], now: created.addingTimeInterval(60))
        #expect(kinds(entries) == ["created"])
    }

    @Test("The lock line appears at exactly 24 hours, not a second before")
    func lockLineAppearsAtTheLock() {
        let record = makeRecord(createdAt: created)
        let before = RecordTrailBuilder.entries(
            for: record, corrections: [], now: created.addingTimeInterval(24 * 3600 - 1)
        )
        let at = RecordTrailBuilder.entries(for: record, corrections: [], now: created.addingTimeInterval(24 * 3600))
        #expect(kinds(before) == ["created"])
        #expect(kinds(at) == ["locked", "created"])
        #expect(at.first?.date == record.lockedAt)
    }

    @Test("Newest first: corrections, then the lock, then the creation")
    func ordering() {
        let record = makeRecord(createdAt: created)
        let corrections = [
            makeCorrection(recordID: record.id, createdAt: created.addingTimeInterval(3 * 24 * 3600)),
            makeCorrection(recordID: record.id, createdAt: created.addingTimeInterval(2 * 24 * 3600))
        ]
        let entries = RecordTrailBuilder.entries(
            for: record, corrections: corrections, now: created.addingTimeInterval(4 * 24 * 3600)
        )
        #expect(kinds(entries) == ["correction", "correction", "locked", "created"])
        #expect(entries.map(\.date) == entries.map(\.date).sorted(by: >))
    }

    @Test("Another record's corrections are not in this trail")
    func ignoresOtherRecords() {
        let record = makeRecord(createdAt: created)
        let other = makeRecord(createdAt: created)
        let entries = RecordTrailBuilder.entries(
            for: record, corrections: [makeCorrection(recordID: other.id, createdAt: created.addingTimeInterval(1))],
            now: created.addingTimeInterval(60)
        )
        #expect(kinds(entries) == ["created"])
    }

    @Test("Lines with the same time keep the story in order: the later step sorts newer")
    func ties() {
        let record = makeRecord(createdAt: created)
        let atLock = makeCorrection(recordID: record.id, createdAt: record.lockedAt)
        let entries = RecordTrailBuilder.entries(
            for: record, corrections: [atLock], now: record.lockedAt.addingTimeInterval(1)
        )
        #expect(kinds(entries) == ["correction", "locked", "created"])
    }

    @Test("The creation line carries how it was made")
    func createdDetail() {
        let record = makeRecord(createdAt: created, source: .voice, result: .neutral, products: ["Calming serum"])
        let entries = RecordTrailBuilder.entries(for: record, corrections: [], now: created)
        guard case .created(let source, let result, let products) = entries[0].kind else {
            Issue.record("not a creation line")
            return
        }
        #expect(source == .voice)
        #expect(result == .neutral)
        #expect(products == ["Calming serum"])
    }

    @Test("A draft finalized later shows when it was finalized, and its lock counts from then")
    func finalizedDraft() {
        var record = TreatmentRecord(clientID: UUID(), serviceName: "Glow", createdAt: created, status: .draft)
        let finalizedAt = created.addingTimeInterval(5 * 3_600)
        record.finalize(at: finalizedAt)
        let open = RecordTrailBuilder.entries(for: record, corrections: [], now: created.addingTimeInterval(86_400))
        let locked = RecordTrailBuilder.entries(for: record, corrections: [], now: record.lockedAt)

        #expect(kinds(open) == ["finalized", "created"])
        #expect(kinds(locked) == ["locked", "finalized", "created"])
    }

    @Test("A draft never shows a lock line")
    func draftNeverLocks() {
        let record = TreatmentRecord(clientID: UUID(), serviceName: "Glow", createdAt: created, status: .draft)
        let entries = RecordTrailBuilder.entries(for: record, corrections: [], now: created.addingTimeInterval(9e6))

        #expect(kinds(entries) == ["created"])
    }

    @Test("A correction of one of her own fields carries the field's name from the record")
    func entryCorrectionName() {
        var record = makeRecord(createdAt: created)
        record.fieldEntries = [RecordFieldEntry(key: "lashCurl", name: "Curl", kind: .text, value: "C")]
        let correction = RecordCorrection(id: UUID(), recordID: record.id, createdAt: record.lockedAt,
                                          fieldKey: "field.lashCurl", oldValue: "C", newValue: "D", reason: "typo")
        let entries = RecordTrailBuilder.entries(for: record, corrections: [correction], now: record.lockedAt)

        #expect(entries.first?.kind == .correction(correction, entryName: "Curl"))
    }
}
