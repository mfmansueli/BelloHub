//
//  HealthFormViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// The health form sheet: the professional asks the questions of the current template, the client agrees to the
/// consent text and types her name, and one signature creates the sealed `HealthForm` and its `Consent`. The text
/// that is read is the text that is stored: its version and its language go on the consent.
@MainActor
@Observable
final class HealthFormViewModel: Identifiable {
    let id = UUID()
    let client: Client
    let template: HealthFormTemplate
    /// The questions that are on, in the order the template asks them.
    let questions: [HealthQuestion]
    var draft = HealthFormDraft()
    private(set) var textLanguage: AppLocalization
    private(set) var legalText: LegalText?
    private(set) var renderedText: RenderedLegalText?
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var didSave = false

    private let repository: any HealthRepository
    private let legal: any LegalTextLibrary
    private let values: LegalTextValues
    private let now: @Sendable () -> Date
    /// Made once, so saving again after a failure updates the same records instead of adding a second pair.
    private let formID: UUID
    private let consentID: UUID

    init(
        client: Client,
        template: HealthFormTemplate,
        catalog: HealthFormCatalog,
        repository: any HealthRepository,
        legal: any LegalTextLibrary = BundleLegalTextLibrary(),
        profile: ProfessionalProfile?,
        fallbackLanguage: AppLocalization = .en,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.client = client
        self.template = template
        self.questions = template.questionKeys.compactMap { catalog.question(for: $0) }
        self.repository = repository
        self.legal = legal
        self.values = LegalTextValues(profile: profile)
        self.now = now
        self.formID = makeID()
        self.consentID = makeID()
        // The client reads the text in the business language by default; the menu can change it.
        self.textLanguage = profile.flatMap { AppLocalization(rawValue: $0.appLocaleID) } ?? fallbackLanguage
        loadText()
    }

    // MARK: - The consent text

    /// The kind of consent this form will sign: the guardian's for a minor.
    var consentKind: ConsentKind { HealthFormFillRules.consentKind(isForMinor: draft.isForMinor) }

    var hasTextError: Bool { legalText == nil }

    /// Reads the text again for the current kind and language. A different text must be agreed to again.
    private func loadText() {
        draft.agrees = false
        if let found = try? legal.latest(consentKind.legalDocument, localization: textLanguage) {
            legalText = found
            renderedText = LegalTextRenderer.render(found, values: values, pending: .forThisBuild)
        } else {
            legalText = nil
            renderedText = nil
        }
    }

    func setTextLanguage(_ language: AppLocalization) {
        guard language != textLanguage else { return }
        textLanguage = language
        loadText()
    }

    func setForMinor(_ isForMinor: Bool) {
        guard isForMinor != draft.isForMinor else { return }
        draft.isForMinor = isForMinor
        loadText()
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
        !isSaving && legalText != nil && HealthFormFillRules.canSign(draft: draft, questions: questions)
    }

    /// Fire-and-forget entry point for the button; `saveAsync()` is what tests await.
    func save() {
        Task { await saveAsync() }
    }

    /// Saves the consent first, then the form: a failure in between leaves a consent with no answers (she fills the
    /// form again) and never answers with no consent.
    func saveAsync() async {
        guard canSave, let legalText else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let records = HealthFormFillRules.records(
            draft: draft,
            signing: HealthFormFillRules.Signing(
                client: client, template: template, questions: questions, text: legalText, formID: formID,
                consentID: consentID, now: now()
            )
        )
        do {
            try await repository.save(records.consent)
            try await repository.save(records.form)
            didSave = true
        } catch {
            errorMessage = String(localized: "health.error.save")
        }
    }
}
