//
//  PatchTestResult.swift
//  BelloHub
//

/// What the skin did after a patch test.
enum PatchTestResult: String, PersistedEnum {
    case noReaction
    case mildReaction
    case reaction

    /// A value a newer version wrote that this one does not know reads as a reaction: warning too much is the safe
    /// mistake, and the store keeps the original value.
    static let fallback = PatchTestResult.reaction

    /// True for any result the professional should look at before treating.
    var needsAttention: Bool { self != .noReaction }
}
