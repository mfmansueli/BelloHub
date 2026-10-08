//
//  HealthAnswerSummary.swift
//  BelloHub
//

import Foundation

/// Turns a stored health form into the rows the professional reads ("Allergies: Fragrance"), in the language of the
/// screen. Pure: the words for yes, no and none come in as `Labels`, so the rule is tested without a bundle.
enum HealthAnswerSummary {
    /// One line of the answers list.
    struct Row: Identifiable, Hashable, Sendable {
        let key: String
        let name: String
        let value: String
        let isAnswered: Bool

        var id: String { key }
    }

    /// The few words the rows are built from, in the reader's language.
    struct Labels: Equatable, Sendable {
        let yes: String
        let no: String
        let none: String
        let notAnswered: String
    }

    /// The rows of `form`. The questions come first, in the order the form asked them (the template of the version it
    /// was signed on, when it is stored); an answer to a question that is not in that list still shows, so nothing a
    /// client told the professional is ever hidden. An optional note nobody wrote is left out.
    static func rows(
        form: HealthForm,
        template: HealthFormTemplate?,
        catalog: HealthFormCatalog,
        labels: Labels,
        list: ([String]) -> String
    ) -> [Row] {
        var keys = template?.questionKeys ?? []
        let extra = form.answers.keys.filter { !keys.contains($0) }
        let known = catalog.questions.map(\.key)
        func position(_ key: String) -> Int { known.firstIndex(of: key) ?? Int.max }
        keys += extra.filter { known.contains($0) }.sorted { position($0) < position($1) }
        keys += extra.filter { !known.contains($0) }.sorted()

        return keys.compactMap { key in
            let question = catalog.question(for: key)
            let answer = form.answers[key]
            if question?.kind == .text, text(of: answer) == nil { return nil }
            guard let value = value(of: answer, question: question, labels: labels, list: list) else {
                return Row(key: key, name: question?.name ?? key, value: labels.notAnswered, isAnswered: false)
            }
            return Row(key: key, name: question?.name ?? key, value: value, isAnswered: true)
        }
    }

    // MARK: - Values

    private static func text(of answer: HealthAnswer?) -> String? {
        guard case .text(let value)? = answer else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The text of an answer, or nil when there is nothing to show.
    private static func value(
        of answer: HealthAnswer?, question: HealthQuestion?, labels: Labels, list: ([String]) -> String
    ) -> String? {
        switch answer {
        case nil: return nil
        case .yes?: return labels.yes
        case .no?: return labels.no
        case .text?: return text(of: answer)
        case .choices(let keys)?:
            guard !keys.isEmpty else { return nil }
            let ordered = ordered(keys, by: question)
            return list(ordered.map { key in
                key == HealthOption.noneKey ? labels.none : (question?.optionName(for: key) ?? key)
            })
        }
    }

    /// Choices in the order the question lists them; one this version does not know goes last.
    private static func ordered(_ keys: [String], by question: HealthQuestion?) -> [String] {
        guard let question else { return keys }
        let order = question.options.map(\.key)
        return keys.sorted { (order.firstIndex(of: $0) ?? Int.max) < (order.firstIndex(of: $1) ?? Int.max) }
    }
}
