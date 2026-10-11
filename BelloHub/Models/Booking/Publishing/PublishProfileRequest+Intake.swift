//
//  PublishProfileRequest+Intake.swift
//  BelloHub
//

extension PublishProfileRequest {
    /// `publishProfile.profile.intake` (API.md 6.2): the health form the page asks, opaque to the server. D55: no
    /// consent text travels with it. The template is what `web/src/api/parse.ts` (`questionsOf`) reads.
    struct Intake: Encodable, Equatable, Sendable {
        /// The vault's template version: a sealed form comes back with it, so the answers are read against the
        /// questions that were asked.
        var formVersion: Int
        var template: Template
    }

    struct Template: Encodable, Equatable, Sendable {
        var questions: [Question]
    }

    /// One question in every booking language. `kind` is the page's vocabulary: `yesNo`, `multiChoice`, `text`.
    struct Question: Encodable, Equatable, Sendable {
        var key: String
        var kind: String
        /// Locale id to the sentence the client reads.
        var label: [String: String]
        var options: [Option]?
    }

    struct Option: Encodable, Equatable, Sendable {
        /// The option key the app stores (`HealthOption.key`, `none` for "None").
        var value: String
        var label: [String: String]
    }
}
