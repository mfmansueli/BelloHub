//
//  OnboardingRules.swift
//  BelloHub
//

import Foundation

/// The rules of the setup that have no UI: what lets her continue, and how the names she types are cleaned.
/// One owner for each rule; the View and the ViewModel only ask (CLAUDE.md section 2).
enum OnboardingRules {
    static let minimumNameLength = 2
    static let maximumNameLength = 60
    /// Durations the service sheet offers, in minutes.
    static let durationOptions = [
        5, 10, 15, 20, 25, 30, 40, 45, 50, 60, 75, 90, 105, 120, 150, 180, 210, 240, 300, 360, 480
    ]
    /// Follow-up choices of the service sheet, in weeks.
    static let followUpWeekOptions = [2, 3, 4, 6, 8]

    /// Collapses runs of whitespace and trims, so "  Glow   Facial " is stored as "Glow Facial".
    static func cleaned(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func isValidPersonName(_ text: String) -> Bool {
        let cleaned = cleaned(text)
        return cleaned.count >= minimumNameLength && cleaned.count <= maximumNameLength
    }

    /// Whether the Continue button of `step` is enabled.
    static func canContinue(from step: OnboardingStep, draft: OnboardingDraft) -> Bool {
        switch step {
        case .about: isValidPersonName(draft.displayName)
        case .profession: !draft.professions.isEmpty
        default: true
        }
    }

    /// The name to store for a word or phrase she added, or nil when it is empty, too long or already there
    /// (compared without caring about case or accents, so "Protocolo 360" and "protocolo 360" are one name).
    static func acceptedName(_ raw: String, existing: [String]) -> String? {
        let name = cleaned(raw)
        guard !name.isEmpty, name.count <= maximumNameLength else { return nil }
        let key = comparisonKey(name)
        guard !existing.contains(where: { comparisonKey($0) == key }) else { return nil }
        return name
    }

    static func issues(in service: DraftService) -> [ServiceDraftIssue] {
        var found: [ServiceDraftIssue] = []
        if cleaned(service.name).isEmpty { found.append(.nameMissing) }
        if let price = service.priceAmount, price < 0 { found.append(.priceNegative) }
        return found
    }

    private static func comparisonKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
