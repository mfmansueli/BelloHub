//
//  HelpTopics.swift
//  BelloHub
//

import Foundation

/// The static help of 7.10: common questions (catalog keys for the question and the answer) and the ways to reach a
/// person. Pure data, so the list is tested for completeness against the catalog.
enum HelpTopics {
    struct Topic: Equatable, Identifiable, Sendable {
        let id: String
        var questionKey: String { "help.topic.\(id).question" }
        var answerKey: String { "help.topic.\(id).answer" }
    }

    static let topics: [Topic] = [
        Topic(id: "whereData"), Topic(id: "recoveryKey"), Topic(id: "freeRegistrations"), Topic(id: "bookingLink"),
        Topic(id: "export"), Topic(id: "deleteClient")
    ]

    static let supportEmail = "support@bellohub.app"

    /// `mailto:` with a subject in her language; the body stays empty so nothing of hers is pre-filled.
    static func mailURL(subject: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }
}
