//
//  ConsentRecordRules.swift
//  BelloHub
//

import Foundation

/// The rules of the consent records (D55): what a draft needs before it is saved, how a draft becomes a record and a
/// record a draft, how large a document may be, and the words a row shows. Pure, so every rule is tested without
/// a screen.
enum ConsentRecordRules {
    /// A file (a PDF scan of a few pages) above this is not a consent. A photo goes through the photo pipeline and
    /// ends well below it.
    static let maximumDocumentBytes = ConsentDocument.maximumBytes

    /// A label of her own needs at least two characters; a `kind` with no label uses the kind's title.
    static let minimumLabelLength = 2

    // MARK: - Draft

    /// A record can be saved when its label is either empty (the kind names it) or long enough to mean something.
    static func canSave(_ draft: ConsentRecordDraft) -> Bool {
        let label = trimmed(draft.label)
        return label.isEmpty || label.count >= minimumLabelLength
    }

    /// The record the sheet saves. Empty text is stored as nothing, not as an empty string; the date is kept only
    /// for a signed record. `createdAt` is the existing record's day, or `now` for a new one.
    static func record(
        from draft: ConsentRecordDraft, clientID: UUID, id: UUID, createdAt: Date, now: Date
    ) -> ConsentRecord {
        ConsentRecord(
            id: id, clientID: clientID, kind: draft.kind, isSigned: draft.isSigned,
            signedAt: draft.isSigned ? draft.signedAt : nil, createdAt: createdAt, recordID: draft.recordID,
            label: optional(draft.label), note: optional(draft.note), document: draft.document
        )
    }

    /// The draft that edits an existing record. An unsigned record's date starts at today, so switching it on
    /// proposes the day she is looking at it.
    static func draft(from record: ConsentRecord, now: Date) -> ConsentRecordDraft {
        var draft = ConsentRecordDraft(signedAt: record.signedAt ?? now)
        draft.kind = record.kind
        draft.label = record.label ?? ""
        draft.isSigned = record.isSigned
        draft.note = record.note ?? ""
        draft.document = record.document
        draft.recordID = record.recordID
        return draft
    }

    // MARK: - Documents

    /// Whether a file she chose may be kept. Size is the only rule here; the type is the reader's.
    static func acceptsDocument(bytes: Int) -> Bool {
        bytes > 0 && bytes <= maximumDocumentBytes
    }

    // MARK: - Status

    /// Whether the client may be shown as having a signed consent of `kind` (a `photos` one unlocks sharing a photo).
    static func hasSigned(_ kind: ConsentKind, in records: [ConsentRecord]) -> Bool {
        records.contains { $0.kind == kind && $0.isSigned }
    }

    /// The most recent date among the signed records; nil when nothing is signed.
    static func latestSignedDate(in records: [ConsentRecord]) -> Date? {
        records.filter(\.isSigned).map(\.effectiveDate).max()
    }

    // MARK: - Private

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func optional(_ text: String) -> String? {
        let value = trimmed(text)
        return value.isEmpty ? nil : value
    }
}
