//
//  HealthFormDraft.swift
//  BelloHub
//

/// What the professional has entered so far in the health form sheet, before anything is saved. Nothing in it
/// reaches a log or the network: it becomes a sealed `HealthForm` only when she saves. No consent text and no
/// signature (D55): consents are hers to collect in person and are noted as records on the screen.
struct HealthFormDraft: Equatable, Sendable {
    /// By question key. A question with no entry is not answered yet.
    var answers: [String: HealthAnswer] = [:]
    /// The visit is for someone under 18 (D17): the form says so and names the young person.
    var isForMinor = false
    var minorName = ""
}
