//
//  FakeRecordStructuring.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// Structuring that answers with a fixed draft, or fails, and records what it was asked.
actor FakeRecordStructuring: RecordStructuring {
    struct Failure: Error {}

    private let draft: StructuredRecordDraft?
    private(set) var transcripts: [String] = []

    /// A nil draft makes every call throw.
    init(draft: StructuredRecordDraft?) {
        self.draft = draft
    }

    func isAvailable(for locale: Locale) async -> Bool { true }

    func structure(
        transcript: String, fields: [StructuringField], locale: Locale
    ) async throws -> StructuredRecordDraft {
        transcripts.append(transcript)
        guard let draft else { throw Failure() }
        return draft
    }
}
