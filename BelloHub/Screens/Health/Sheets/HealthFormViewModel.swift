//
//  HealthFormViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// The health form sheet: the professional asks the questions of the current template and saves the sealed
/// `HealthForm`. No consent text and no signature (D55): a consent is noted as its own record on the screen.
@MainActor
@Observable
final class HealthFormViewModel: Identifiable {
    let id = UUID()
    let client: Client
    let template: HealthFormTemplate
    /// The questions that are on, in the order the template asks them.
    let questions: [HealthQuestion]
    var draft = HealthFormDraft()
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var didSave = false

    private let repository: any HealthRepository
    private let now: @Sendable () -> Date
    /// Made once, so saving again after a failure updates the same record instead of adding a second one.
    private let formID: UUID

    init(
        client: Client,
        template: HealthFormTemplate,
        catalog: HealthFormCatalog,
        repository: any HealthRepository,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.client = client
        self.template = template
        self.questions = template.questionKeys.compactMap { catalog.question(for: $0) }
        self.repository = repository
        self.now = now
        self.formID = makeID()
    }

    // MARK: - Minor

    func setForMinor(_ isForMinor: Bool) {
        guard isForMinor != draft.isForMinor else { return }
        draft.isForMinor = isForMinor
    }

    // MARK: - Answers

    func answer(for question: HealthQuestion) -> HealthAnswer? {
        draft.answers[question.key]
    }

    func setYesNo(_ isYes: Bool, for question: HealthQuestion) {
        draft.answers[question.key] = isYes ? .yes : .no
    }

    func toggleChoice(_ optionKey: String, for question: HealthQuestion) {
        draft.answers[question.key] = HealthFormFillRules.choosing(
            optionKey, in: draft.answers[question.key], for: question
        )
    }

    func isChoiceOn(_ optionKey: String, for question: HealthQuestion) -> Bool {
        if case .choices(let keys)? = draft.answers[question.key] { return keys.contains(optionKey) }
        return false
    }

    func text(for question: HealthQuestion) -> String {
        if case .text(let value)? = draft.answers[question.key] { return value }
        return ""
    }

    func setText(_ value: String, for question: HealthQuestion) {
        draft.answers[question.key] = value.isEmpty ? nil : .text(value)
    }

    // MARK: - Saving

    var canSave: Bool {
        !isSaving && HealthFormFillRules.canSave(draft: draft, questions: questions)
    }

    /// Fire-and-forget entry point for the button; `saveAsync()` is what tests await.
    func save() {
        Task { await saveAsync() }
    }

    func saveAsync() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let form = HealthFormFillRules.form(
            draft: draft,
            saving: HealthFormFillRules.Saving(
                client: client, template: template, questions: questions, formID: formID, now: now()
            )
        )
        do {
            try await repository.save(form)
            didSave = true
        } catch {
            errorMessage = String(localized: "health.error.save")
        }
    }
}
