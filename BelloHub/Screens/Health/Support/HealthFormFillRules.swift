//
//  HealthFormFillRules.swift
//  BelloHub
//

import Foundation

/// The rules of filling the health form as the professional: when an answer counts, how a choice changes, when the
/// form can be signed, and the records a signature makes. Pure, so every rule is tested without a screen.
enum HealthFormFillRules {
    /// A typed name needs at least this many characters (a single letter is not a signature).
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

    // MARK: - Signing

    static func isValidName(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumNameLength
    }

    /// Everything is answered, the text is agreed to, the signature is typed and, for a minor, her name is there.
    static func canSign(draft: HealthFormDraft, questions: [HealthQuestion]) -> Bool {
        unansweredKeys(questions: questions, draft: draft).isEmpty
            && draft.agrees
            && isValidName(draft.signature)
            && (!draft.isForMinor || isValidName(draft.minorName))
    }

    /// A minor's consent is the guardian's, on its own text (D17).
    static func consentKind(isForMinor: Bool) -> ConsentKind {
        isForMinor ? .guardian : .treatment
    }

    // MARK: - Records

    /// What a signature is made of besides the draft: who it is for, the version of the form asked, the text that was
    /// read, the ids of the two records and the moment.
    struct Signing: Sendable {
        let client: Client
        let template: HealthFormTemplate
        let questions: [HealthQuestion]
        let text: LegalText
        let formID: UUID
        let consentID: UUID
        let now: Date
    }

    /// The form and the consent one signature creates. Both carry the exact version and localization of the text that
    /// was read, so it can be shown again exactly. Answers of questions that are off are never stored.
    static func records(draft: HealthFormDraft, signing: Signing) -> (form: HealthForm, consent: Consent) {
        var answers: [String: HealthAnswer] = [:]
        for question in signing.questions {
            guard let answer = draft.answers[question.key], isAnswered(question, answer) else { continue }
            if case .text(let value) = answer {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { answers[question.key] = .text(trimmed) }
            } else {
                answers[question.key] = answer
            }
        }
        let signature = draft.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        let form = HealthForm(
            id: signing.formID, clientID: signing.client.id, formVersion: signing.template.version,
            filledBy: .professional, isForMinor: draft.isForMinor, signedAt: signing.now, importedFromItemID: nil,
            answers: answers,
            signatureImage: nil, guardianName: draft.isForMinor ? signature : nil,
            minorName: draft.isForMinor ? draft.minorName.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        )
        let consent = Consent(
            id: signing.consentID, clientID: signing.client.id, kind: consentKind(isForMinor: draft.isForMinor),
            signedAt: signing.now, textVersion: signing.text.version, localeID: signing.text.localization,
            typedSignature: signature, signatureImage: nil
        )
        return (form, consent)
    }
}
