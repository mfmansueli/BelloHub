//
//  TreatmentRecordDecodingTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("TreatmentRecord decoding")
struct TreatmentRecordDecodingTests {
    private let created = TestClock.date("2026-09-30 17:42")

    /// The JSON a record had before drafts and the visit date existed: no `status`, `performedAt` or `finalizedAt`.
    private func legacyJSON(lockedAt: Date) throws -> Data {
        let object: [String: Any] = [
            "id": UUID().uuidString, "clientID": UUID().uuidString, "serviceName": "Glow Facial",
            "createdAt": created.timeIntervalSinceReferenceDate,
            "lockedAt": lockedAt.timeIntervalSinceReferenceDate,
            "source": "manual", "result": "good", "aiAssisted": false,
            "notes": "old note", "productsUsed": ["serum"]
        ]
        return try JSONSerialization.data(withJSONObject: object)
    }

    @Test("A record from before drafts reads as finalized, keeps its lock and gets no invented visit day")
    func legacyRecord() throws {
        let lock = RecordLockPolicy.lockedAt(createdAt: created)
        let record = try JSONDecoder().decode(TreatmentRecord.self, from: legacyJSON(lockedAt: lock))

        #expect(record.status == .finalized)
        #expect(record.lockedAt == lock)
        #expect(record.performedAt == nil)
        #expect(record.finalizedAt == nil)
        #expect(record.reaction == nil)
        #expect(record.nextVisitReminder == nil)
        #expect(record.notes == "old note")
        #expect(record.result == .good)
    }

    @Test("Today's shape round-trips with every new field")
    func roundTrip() throws {
        let visit = TestClock.date("2026-09-28 10:00")
        let record = TreatmentRecord(clientID: UUID(), serviceName: "Lashes", createdAt: created, performedAt: visit,
                                     status: .draft, reaction: "slight redness", nextVisitReminder: "less volume")
        let decoded = try JSONDecoder().decode(TreatmentRecord.self, from: JSONEncoder().encode(record))

        #expect(decoded == record)
        #expect(decoded.lockedAt == RecordLockPolicy.draftLockedAt)
    }

    @Test("Finalizing starts the 24-hour lock at that moment and only once")
    func finalize() {
        var record = TreatmentRecord(clientID: UUID(), serviceName: "Glow", createdAt: created, status: .draft)
        let later = created.addingTimeInterval(30 * 3_600)
        record.finalize(at: later)
        record.finalize(at: later.addingTimeInterval(3_600))

        #expect(record.status == .finalized)
        #expect(record.finalizedAt == later)
        #expect(record.lockedAt == later.addingTimeInterval(86_400))
    }

    @Test("A draft has no lock countdown; a finalized record does")
    func remaining() {
        let draft = TreatmentRecord(clientID: UUID(), serviceName: "Glow", createdAt: created, status: .draft)
        let finalized = TreatmentRecord(clientID: UUID(), serviceName: "Glow", createdAt: created)

        #expect(RecordLockPolicy.remaining(of: draft, now: created) == nil)
        #expect(RecordLockPolicy.remaining(of: finalized, now: created) == 86_400)
        #expect(!RecordLockPolicy.isLocked(lockedAt: draft.lockedAt, now: created.addingTimeInterval(400 * 86_400)))
    }
}
