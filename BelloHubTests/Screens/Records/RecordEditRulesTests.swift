//
//  RecordEditRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RecordEditRules")
struct RecordEditRulesTests {
    private let createdAt = TestClock.now

    // MARK: - The 24-hour lock

    @Test(
        "A record is editable until its 24th hour and needs a correction from then on",
        arguments: [
            (TimeInterval(0), RecordLockPolicy.EditPath.editDirectly),
            (TimeInterval(24 * 3600 - 1), .editDirectly), // 23:59:59
            (TimeInterval(24 * 3600), .addCorrection), // 24:00:00
            (TimeInterval(24 * 3600 + 1), .addCorrection),
            (TimeInterval(7 * 24 * 3600), .addCorrection)
        ]
    )
    func path(elapsed: TimeInterval, expected: RecordLockPolicy.EditPath) {
        let record = makeRecord(createdAt: createdAt)
        #expect(RecordEditRules.path(for: record, now: createdAt.addingTimeInterval(elapsed)) == expected)
    }

    // MARK: - What the record says now

    @Test("With no correction a field says what the record says")
    func currentValueWithoutCorrections() {
        let record = makeRecord(notes: "Original note")
        #expect(RecordEditRules.currentValue(of: .notes, in: record, corrections: []) == "Original note")
    }

    @Test("The latest correction of a field wins, and other fields and other records do not matter")
    func currentValueUsesLatestCorrection() {
        let record = makeRecord(aftercare: "Original")
        let other = makeRecord()
        let corrections = [
            makeCorrection(recordID: record.id, createdAt: TestClock.days(-2), old: "Original", new: "First fix"),
            makeCorrection(recordID: record.id, createdAt: TestClock.days(-1), old: "First fix", new: "Second fix"),
            makeCorrection(recordID: record.id, createdAt: TestClock.now, field: .technique, new: "Not this field"),
            makeCorrection(recordID: other.id, createdAt: TestClock.now, new: "Other record")
        ]
        #expect(RecordEditRules.currentValue(of: .aftercare, in: record, corrections: corrections) == "Second fix")
    }

    @Test("A correction that clears a field makes it say nothing")
    func clearedFieldSaysNothing() {
        let record = makeRecord(aftercare: "Original")
        let corrections = [makeCorrection(recordID: record.id, old: "Original", new: nil)]
        #expect(RecordEditRules.currentValue(of: .aftercare, in: record, corrections: corrections) == nil)
    }

    // MARK: - Problems

    struct ProblemCase: CustomTestStringConvertible {
        let name: String
        let newValue: String
        let reason: String
        let elapsed: TimeInterval
        let expected: RecordEditRules.Problem?
        var testDescription: String { name }
    }

    @Test("What stops a change from being saved", arguments: [
        ProblemCase(name: "locked, same text", newValue: "Skin a little sensitive.", reason: "Why",
                    elapsed: 25 * 3600, expected: .unchanged),
        ProblemCase(name: "locked, same text with spaces around", newValue: "  Skin a little sensitive.  ",
                    reason: "Why", elapsed: 25 * 3600, expected: .unchanged),
        ProblemCase(name: "locked, new text and no reason", newValue: "New", reason: "   ",
                    elapsed: 25 * 3600, expected: .reasonMissing),
        ProblemCase(name: "locked, new text and a reason", newValue: "New", reason: "Typo",
                    elapsed: 25 * 3600, expected: nil),
        ProblemCase(name: "open, new text needs no reason", newValue: "New", reason: "",
                    elapsed: 3600, expected: nil),
        ProblemCase(name: "open, same text", newValue: "Skin a little sensitive.", reason: "",
                    elapsed: 3600, expected: .unchanged),
        ProblemCase(name: "just before the lock, no reason needed", newValue: "New", reason: "",
                    elapsed: 24 * 3600 - 1, expected: nil),
        ProblemCase(name: "at the lock, reason needed", newValue: "New", reason: "",
                    elapsed: 24 * 3600, expected: .reasonMissing)
    ])
    func problem(_ testCase: ProblemCase) {
        let record = makeRecord(createdAt: createdAt, notes: "Skin a little sensitive.")
        let draft = RecordCorrectionDraft(
            recordID: record.id, field: .standard(.notes), newValue: testCase.newValue, reason: testCase.reason
        )
        let problem = RecordEditRules.problem(
            for: draft, record: record, corrections: [], now: createdAt.addingTimeInterval(testCase.elapsed)
        )
        #expect(problem == testCase.expected)
    }

    // MARK: - The logged correction

    @Test("A correction keeps what the field said, what it says now and why, trimmed")
    func correctionContent() {
        let record = makeRecord(aftercare: "Original")
        let earlier = makeCorrection(recordID: record.id, old: "Original", new: "First fix")
        let id = UUID()
        let draft = RecordCorrectionDraft(
            recordID: record.id, field: .standard(.aftercare), newValue: "  Second fix ", reason: " Client called "
        )
        let correction = RecordEditRules.correction(
            id: id, draft: draft, record: record, corrections: [earlier], now: TestClock.now
        )
        #expect(correction.id == id)
        #expect(correction.recordID == record.id)
        #expect(correction.fieldKey == "aftercare")
        #expect(correction.oldValue == "First fix")
        #expect(correction.newValue == "Second fix")
        #expect(correction.reason == "Client called")
        #expect(correction.createdAt == TestClock.now)
    }

    @Test("Emptying a field is stored as nil")
    func emptyingAField() {
        let record = makeRecord(notes: "Note")
        let draft = RecordCorrectionDraft(
            recordID: record.id, field: .standard(.notes), newValue: "   ", reason: "Remove"
        )
        let correction = RecordEditRules.correction(
            id: UUID(), draft: draft, record: record, corrections: [], now: TestClock.now
        )
        #expect(correction.newValue == nil)
        #expect(correction.oldValue == "Note")
    }

    @Test("Every correctable field reads and writes its own part of the record")
    func fieldsRoundTrip() {
        let record = makeRecord()
        for field in RecordCorrectableField.allCases {
            let changed = field.setting("changed \(field.rawValue)", in: record)
            #expect(field.originalValue(in: changed) == "changed \(field.rawValue)")
            for other in RecordCorrectableField.allCases where other != field {
                #expect(other.originalValue(in: changed) == other.originalValue(in: record))
            }
        }
    }
}
