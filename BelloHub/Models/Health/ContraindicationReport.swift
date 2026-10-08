//
//  ContraindicationReport.swift
//  BelloHub
//

/// What `ContraindicationMatcher` found for one service and one client. It **warns and never blocks** (D16): the
/// clinical decision is the professional's, so nothing here can stop a booking.
struct ContraindicationReport: Equatable, Sendable {
    /// One of the service's contraindications that the client's answers trigger.
    struct Match: Hashable, Sendable {
        /// The token as the service lists it (`pregnancy`, `allergies.latex`, `minor`).
        let token: String
        /// The question the answer belongs to; nil for the `minor` token, which comes from the form itself.
        let questionKey: String?
        /// The choice that triggered it, for a token of the form `question.choice`.
        let optionKey: String?
    }

    /// In the order the service lists its contraindications.
    let matches: [Match]
    /// Contraindications the answers cannot decide: text the professional wrote herself, or a key this version does
    /// not know. The screen can show them as a reminder to ask.
    let unchecked: [String]
    /// False when the client has no health form yet, so an empty `matches` means "unknown", not "fine".
    let hasHealthForm: Bool

    var hasWarnings: Bool { !matches.isEmpty }

    /// Nothing to check: the service lists no contraindication.
    static let none = ContraindicationReport(matches: [], unchecked: [], hasHealthForm: true)
}
