//
//  ClientFormDraft.swift
//  BelloHub
//

import Foundation

/// What the new-client and edit-client forms hold while she types: raw text, not yet a `Client`. The rules that turn it
/// into one, validate it and tell whether it changed are in `ClientFormRules`.
struct ClientFormDraft: Equatable, Sendable {
    var name = ""
    /// As typed ("11 98123-4410"); normalized to international form on save.
    var phone = ""
    var confirmPhone = ""
    var email = ""
    var confirmEmail = ""
    /// In the order she chose them.
    var tagIDs: [UUID] = []
    var importantNote = ""
    var birthday = BirthdayInput()
    var onlineBookingStopped = false
    var stopReason = ""
    var remindersEnabled = true

    /// The same draft with surrounding spaces removed from every text, the form the rules compare and save.
    var trimmed: ClientFormDraft {
        var copy = self
        copy.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.confirmPhone = confirmPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.confirmEmail = confirmEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.importantNote = importantNote.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.stopReason = stopReason.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}
