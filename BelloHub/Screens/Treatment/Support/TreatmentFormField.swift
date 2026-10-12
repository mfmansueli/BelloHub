//
//  TreatmentFormField.swift
//  BelloHub
//

import Foundation

/// One question of the treatment form, resolved from the profession's record template: its key, the name in her
/// language, how she answers it and where the answer lives in the saved record.
struct TreatmentFormField: Identifiable, Equatable, Sendable {
    /// How she fills it in.
    enum Input: Equatable, Sendable {
        case text
        case number(unit: String?)
        case choice([String])
        case multiChoice([String])
        case yesNo
        /// A list of products, one chip each.
        case products
    }

    /// Where the answer is saved. The first field of a role takes the record's own property; the others (a second
    /// profession's "Result", say) go to `generic` so nothing overwrites anything.
    enum Role: Equatable, Sendable {
        case notes
        case products
        case technique
        case result
        case aftercare
        case nextSession
        /// How the client reacted, in her words (`TreatmentRecord.reaction`).
        case reaction
        /// What to remember at the next visit (`TreatmentRecord.nextVisitReminder`).
        case nextVisitReminder
        case generic
    }

    /// The reserved keys of the fields every record has, whatever her template says.
    static let notesKey = "notes"
    static let nextSessionKey = "nextSession"
    static let reactionKey = "reaction"
    static let reminderKey = "nextVisitReminder"
    /// Used only when her template has no aftercare field of its own.
    static let aftercareKey = "aftercare"

    let key: String
    let name: String
    let input: Input
    let role: Role

    var id: String { key }

    /// How the field is described to the structuring technology (`StructuringField`).
    var structuringKind: RecordFieldKind {
        switch input {
        case .text, .products: .text
        case .number: .number
        case .choice: .choice
        case .multiChoice: .multiChoice
        case .yesNo: .yesNo
        }
    }
}
