//
//  RecordCorrectionDraft.swift
//  BelloHub
//

import Foundation

/// What she is typing into the correction (or edit) sheet for one record.
struct RecordCorrectionDraft: Identifiable, Equatable {
    let recordID: UUID
    var field: RecordEditableField = .standard(.notes)
    var newValue = ""
    var reason = ""

    var id: UUID { recordID }
}
