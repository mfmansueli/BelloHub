//
//  ContraindicationMatcher.swift
//  BelloHub
//

import Foundation

/// Compares a service's contraindications with a client's health answers (D16: it warns, it never blocks). A
/// contraindication is a token that names an answer:
/// - `pregnancy`: the question is answered yes, or (for text and choices) has an answer other than "None";
/// - `allergies.latex`: the choice `latex` is ticked on the `allergies` question;
/// - `minor`: the form was filled for someone under 18 (D17).
/// Anything else (a note she typed, a key from a newer version) is returned as `unchecked`, never silently dropped.
/// Pure: S6 calls it when a visit is booked.
enum ContraindicationMatcher {
    /// The one token that comes from the form instead of a question.
    static let minorToken = "minor"

    /// A token the service editor can offer, with the wording of the question and, for a choice, of the choice.
    struct Choice: Hashable, Identifiable, Sendable {
        let token: String
        let questionName: String
        let optionName: String?

        var id: String { token }
    }

    /// Every token the catalog can decide, in catalog order, for the service editor's picker.
    static func choices(in catalog: HealthFormCatalog) -> [Choice] {
        catalog.questions.flatMap { question -> [Choice] in
            switch question.kind {
            case .yesNo:
                return [Choice(token: question.key, questionName: question.name, optionName: nil)]
            case .choices:
                return question.options.map {
                    Choice(token: "\(question.key).\($0.key)", questionName: question.name, optionName: $0.name)
                }
            case .text:
                return []
            }
        }
    }

    /// The warnings for `contraindications` against the client's latest form (nil when she has none).
    static func check(
        contraindications: [String], form: HealthForm?, catalog: HealthFormCatalog
    ) -> ContraindicationReport {
        var matches: [ContraindicationReport.Match] = []
        var unchecked: [String] = []
        var seen: Set<String> = []
        for raw in contraindications {
            let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty, seen.insert(token).inserted else { continue }
            guard let parsed = parse(token, in: catalog) else {
                unchecked.append(token)
                continue
            }
            guard let form else { continue }
            if isTriggered(parsed, by: form) {
                matches.append(ContraindicationReport.Match(
                    token: token, questionKey: parsed.questionKey, optionKey: parsed.optionKey
                ))
            }
        }
        return ContraindicationReport(matches: matches, unchecked: unchecked, hasHealthForm: form != nil)
    }

    // MARK: - Parsing and matching

    private struct Parsed {
        let questionKey: String?
        let optionKey: String?
    }

    /// Nil when the catalog cannot decide this token.
    private static func parse(_ token: String, in catalog: HealthFormCatalog) -> Parsed? {
        if token == minorToken { return Parsed(questionKey: nil, optionKey: nil) }
        let parts = token.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard let questionKey = parts.first, let question = catalog.question(for: questionKey) else { return nil }
        if parts.count == 1 { return Parsed(questionKey: questionKey, optionKey: nil) }
        let optionKey = parts[1]
        guard question.kind == .choices, question.optionName(for: optionKey) != nil else { return nil }
        return Parsed(questionKey: questionKey, optionKey: optionKey)
    }

    private static func isTriggered(_ parsed: Parsed, by form: HealthForm) -> Bool {
        guard let questionKey = parsed.questionKey else { return form.isForMinor }
        guard let answer = form.answers[questionKey] else { return false }
        switch answer {
        case .yes:
            return parsed.optionKey == nil
        case .no:
            return false
        case .text(let value):
            return parsed.optionKey == nil && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .choices(let keys):
            if let optionKey = parsed.optionKey { return keys.contains(optionKey) }
            return keys.contains { $0 != HealthOption.noneKey }
        }
    }
}
