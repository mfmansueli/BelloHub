//
//  RecordStructuring.swift
//  BelloHub
//

import Foundation

/// Turns a transcript into a draft of the profession's record fields. The AI sits behind this protocol (D53): v1
/// ships the screens and a fake; the owner refines the real service later. It runs on the device (docs/12) and a
/// transcript never goes to a server.
protocol RecordStructuring: Sendable {
    func isAvailable(for locale: Locale) async -> Bool
    func structure(
        transcript: String, fields: [StructuringField], locale: Locale
    ) async throws -> StructuredRecordDraft
}

/// The v1 default: no AI yet, so the flow goes to the manual form.
struct UnavailableRecordStructuring: RecordStructuring {
    struct NotAvailable: Error {}

    func isAvailable(for locale: Locale) async -> Bool { false }

    func structure(
        transcript: String, fields: [StructuringField], locale: Locale
    ) async throws -> StructuredRecordDraft {
        throw NotAvailable()
    }
}
