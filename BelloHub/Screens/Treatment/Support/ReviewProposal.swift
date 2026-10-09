//
//  ReviewProposal.swift
//  BelloHub
//

import Foundation

/// One field the technology proposed from the transcript, and what she decided about it. Nothing is saved from a
/// proposal until she has accepted, edited or dropped it (`ReviewMerge`).
struct ReviewProposal: Identifiable, Equatable, Sendable {
    enum Decision: Equatable, Sendable {
        case pending
        case accepted
        /// She changed the text; an empty edit is the same as dropping it.
        case edited(String)
        case dropped
    }

    let field: TreatmentFormField
    let proposed: String
    var decision: Decision = .pending

    var id: String { field.key }

    var isPending: Bool { decision == .pending }

    /// The answer that goes into the record, or nil when she dropped it (or emptied it).
    var finalValue: String? {
        switch decision {
        case .accepted: proposed
        case .edited(let text): text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
        case .pending, .dropped: nil
        }
    }

    /// What the card shows while she decides: her edit once she made one, the proposal otherwise.
    var shownValue: String {
        if case .edited(let text) = decision { return text }
        return proposed
    }
}
