//
//  ConsentRecordDraft.swift
//  BelloHub
//

import Foundation

/// What the professional has entered in the consent sheet, before anything is saved. Nothing in it reaches a log or
/// the network: it becomes a sealed `ConsentRecord` only when she saves.
struct ConsentRecordDraft: Equatable, Sendable {
    var kind = ConsentKind.treatment
    var label = ""
    var isSigned = true
    /// The day it was signed; shown and stored only while `isSigned` is on.
    var signedAt: Date
    var note = ""
    var document: ConsentDocument?

    init(signedAt: Date) {
        self.signedAt = signedAt
    }
}
