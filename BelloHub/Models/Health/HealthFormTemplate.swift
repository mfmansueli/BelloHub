//
//  HealthFormTemplate.swift
//  BelloHub
//

import Foundation

/// One version of the health form the professional asks: which questions are on, and how often she asks again.
/// Versions are never rewritten. Editing the questions creates the next version, so a form signed on version 2 can
/// always be read against the questions version 2 asked (`HealthForm.formVersion`), and a signed form is never
/// touched (docs/05-DATA-MODEL.md). Stored in the clear: which questions she asks is not clinical.
struct HealthFormTemplate: Identifiable, Hashable, Codable, Sendable {
    let version: Int
    /// The questions that are on, in the order the form asks them (catalog order). A key this version of the app
    /// does not know is kept, so editing on an old build never drops a question a newer build turned on.
    var questionKeys: [String]
    /// "Ask again every": a client is asked to review her answers this many months after she signed.
    var reviewEveryMonths: Int
    let createdAt: Date
    var updatedAt: Date

    /// Derived from the version, so two phones that both create version 3 write the same record instead of two.
    var id: UUID { Self.id(forVersion: version) }

    init(version: Int, questionKeys: [String], reviewEveryMonths: Int, createdAt: Date, updatedAt: Date? = nil) {
        self.version = version
        self.questionKeys = questionKeys
        self.reviewEveryMonths = reviewEveryMonths
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    static func id(forVersion version: Int) -> UUID {
        let digits = String(format: "%012d", max(version, 0))
        return UUID(uuidString: "B3110000-0000-4000-8002-\(digits)") ?? UUID()
    }

    func asks(_ questionKey: String) -> Bool {
        questionKeys.contains(questionKey)
    }
}
