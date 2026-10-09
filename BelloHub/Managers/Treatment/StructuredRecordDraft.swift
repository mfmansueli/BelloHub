//
//  StructuredRecordDraft.swift
//  BelloHub
//

import Foundation

/// What the AI proposes from a transcript: a value per record field of the profession (by the field's `key`) and a
/// short summary. Nothing saves from it: the review screen shows it field by field and she accepts, edits or drops
/// each one (`TreatmentRecord.aiAssisted` is set only after that review).
struct StructuredRecordDraft: Equatable, Sendable {
    var values: [String: String]
    var summary: String?
}

/// One field the structuring may fill: the template's key, its name in her language and its kind.
struct StructuringField: Equatable, Sendable {
    let key: String
    let name: String
    let kind: RecordFieldKind
}
