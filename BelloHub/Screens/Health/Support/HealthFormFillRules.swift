//
//  HealthFormFillRules.swift
//  BelloHub
//

import Foundation

/// The rules of filling the health form as the professional: when an answer counts, how a choice changes, when the
/// form can be saved, and the record a save makes. Pure, so every rule is tested without a screen.
enum HealthFormFillRules {
    /// A name needs at least this many characters (a single letter is not a name).
    static let minimumNameLength = 2

    // MARK: - Answers

    /// Whether `answer` counts as an answer to `question`. A yes or no and a choice must be given explicitly: a
    /// form that silently says "no" is a clinical risk. A free-text note is optional.
    static func isAnswered(_ question: HealthQuestion, _ answer: HealthAnswer?) -> Bool {
        switch question.kind {
        case .text:
            return true
        case .yesNo:
            return answer == .yes || answer == .no
        case .choices:
            if case .choices(let keys)? = answer { return !keys.isEmpty }
            return false
        }
    }

    /// The keys of the questions still waiting for an answer, in the order they are asked.
    static func unansweredKeys(questions: [HealthQuestion], draft: HealthFormDraft) -> [String] {
        questions.filter { !isAnswered($0, draft.answers[$0.key]) }.map(\.key)
    }

    /// The answer after she taps a choice. "None" is exclusive: choosing it clears the others, and choosing another
    /// choice clears it. Tapping a ticked choice unticks it, and no choice left means unanswered (nil). The stored
    /// order follows the question, so the same set of choices always reads the same.
    static func choosing(
        _ optionKey: String, in current: HealthAnswer?, for question: HealthQuestion
    ) -> HealthAnswer? {
        var keys: [String] = []
        if case .choices(let existing)? = current { keys = existing }
        if optionKey == HealthOption.noneKey {
            keys = keys.contains(HealthOption.noneKey) ? [] : [HealthOption.noneKey]
        } else {
            keys.removeAll { $0 == HealthOption.noneKey }
            if let index = keys.firstIndex(of: optionKey) { keys.remove(at: index) } else { keys.append(optionKey) }
        }
        guard !keys.isEmpty else { return nil }
        let order = question.options.map(\.key)
        keys.sort { (order.firstIndex(of: $0) ?? Int.max) < (order.firstIndex(of: $1) ?? Int.max) }
        return .choices(keys)
    }

    // MARK: - Saving

    static func isValidName(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumNameLength
    }

    /// Everything is answered and, for a minor, her name is there. No agreement and no signature (D55).
    static func canSave(draft: HealthFormDraft, questions: [HealthQuestion]) -> Bool {
        unansweredKeys(questions: questions, draft: draft).isEmpty
            && (!draft.isForMinor || isValidName(draft.minorName))
    }

    // MARK: - Record

    /// What a save is made of besides the draft: who it is for, the version of the form asked, the id of the record
    /// and the moment.
    struct Saving: Sendable {
        let client: Client
        let template: HealthFormTemplate
        let questions: [HealthQuestion]
        let formID: UUID
        let now: Date
    }

    /// The form a save creates, on the template's version. Answers of questions that are off are never stored.
    static func form(draft: HealthFormDraft, saving: Saving) -> HealthForm {
        var answers: [String: HealthAnswer] = [:]
        for question in saving.questions {
            guard let answer = draft.answers[question.key], isAnswered(question, answer) else { continue }
            if case .text(let value) = answer {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { answers[question.key] = .text(trimmed) }
            } else {
                answers[question.key] = answer
            }
        }
        return HealthForm(
            id: saving.formID, clientID: saving.client.id, formVersion: saving.template.version,
            filledBy: .professional, isForMinor: draft.isForMinor, signedAt: saving.now, importedFromItemID: nil,
            answers: answers,
            minorName: draft.isForMinor ? draft.minorName.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )
    }
}
