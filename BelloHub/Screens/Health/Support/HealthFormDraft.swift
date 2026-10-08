//
//  HealthFormDraft.swift
//  BelloHub
//

/// What the professional has entered so far in the health form sheet, before anything is saved. Nothing in it
/// reaches a log or the network: it becomes a sealed `HealthForm` and `Consent` only when she saves.
struct HealthFormDraft: Equatable, Sendable {
    /// By question key. A question with no entry is not answered yet.
    var answers: [String: HealthAnswer] = [:]
    /// The visit is for someone under 18 (D17): the guardian consent is the text signed.
    var isForMinor = false
    var minorName = ""
    /// She ticked "I have read this text and I agree".
    var agrees = false
    /// The typed signature. For a minor it is the parent or guardian's name.
    var signature = ""
}
