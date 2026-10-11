//
//  FormTemplatesViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// Screen 6.14: which questions the health form asks and how often she asks again. No consent texts (D55).
/// Saving goes through `HealthFormTemplateRules.edited`: changing the questions starts a new version and never touches
/// a form that was already signed; changing only "ask again every" updates the current version.
@MainActor
@Observable
final class FormTemplatesViewModel {
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var catalog: HealthFormCatalog?
    /// The version she asks today, as stored.
    private(set) var template: HealthFormTemplate?
    /// The questions the list offers: what applies to her professions plus anything already on.
    private(set) var offered: [HealthQuestion] = []
    private(set) var isSaving = false
    /// True from a successful save until she changes something again, for the "Saved" button.
    private(set) var didSave = false
    var enabledKeys: Set<String> = [] {
        didSet { if enabledKeys != oldValue { didSave = false } }
    }
    var reviewMonths = HealthFormTemplateRules.defaultReviewMonths {
        didSet { if reviewMonths != oldValue { didSave = false } }
    }
    private let repository: (any HealthRepository)?
    private let profile: ProfileService
    private let catalogProvider: any HealthFormCatalogProviding
    private let localization: AppLocalization
    private let now: @Sendable () -> Date

    init(
        repository: (any HealthRepository)?,
        profile: ProfileService,
        catalogProvider: any HealthFormCatalogProviding = BundleHealthFormCatalogProvider(),
        locale: Locale = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.profile = profile
        self.catalogProvider = catalogProvider
        self.localization = AppLocalization(locale: locale)
        self.now = now
    }

    // MARK: - Loading

    /// Fire-and-forget entry point for a retry button; `load()` is what the screen awaits.
    func reload() {
        Task { await load() }
    }

    /// Reads the catalog and the version she asks today (storing the default as version 1 the first time, so a form
    /// signed on it can always find its questions). A second call while one is running does nothing.
    func load() async {
        guard !isLoading else { return }
        guard let repository else {
            errorMessage = String(interface: LocalizedStringResource("formTemplates.error.load"))
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let professions = profile.profile?.professions ?? []
        do {
            let loadedCatalog = try catalogProvider.catalog(for: localization)
            let current = try await repository.currentHealthFormTemplate(
                catalog: loadedCatalog, professions: professions, now: now()
            )
            catalog = loadedCatalog
            template = current
            offered = HealthFormTemplateRules.offeredQuestions(in: loadedCatalog, for: professions, template: current)
            enabledKeys = Set(current.questionKeys)
            reviewMonths = current.reviewEveryMonths
            didSave = false
            hasLoaded = true
        } catch {
            errorMessage = String(interface: LocalizedStringResource("formTemplates.error.load"))
        }
    }

    // MARK: - Editing

    func isOn(_ question: HealthQuestion) -> Bool {
        enabledKeys.contains(question.key)
    }

    func setOn(_ isOn: Bool, for question: HealthQuestion) {
        if isOn { enabledKeys.insert(question.key) } else { enabledKeys.remove(question.key) }
    }

    /// The questions that are on, among the ones this version of the app knows.
    private var enabledKnownCount: Int {
        offered.filter { enabledKeys.contains($0.key) }.count
    }

    /// What saving would store, or nil before the screen has loaded.
    private var edited: HealthFormTemplate? {
        guard let catalog, let template else { return nil }
        return HealthFormTemplateRules.edited(
            template, enabling: enabledKeys, reviewEveryMonths: reviewMonths, in: catalog, now: now()
        )
    }

    var hasChanges: Bool {
        guard let template, let edited else { return false }
        return edited != template
    }

    /// At least one question must stay on: a form that asks nothing is not a health form.
    var hasNoQuestionsOn: Bool { hasLoaded && enabledKnownCount == 0 }

    var canSave: Bool { !isSaving && hasChanges && !hasNoQuestionsOn }

    /// The version she asks today. Saving a change to the questions makes it the next one.
    var currentVersion: Int? { template?.version }

    // MARK: - Saving

    /// Fire-and-forget entry point for the button; `saveAsync()` is what tests await.
    func save() {
        Task { await saveAsync() }
    }

    func saveAsync() async {
        guard canSave, let repository, let edited else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await repository.save(edited)
            template = edited
            enabledKeys = Set(edited.questionKeys)
            reviewMonths = edited.reviewEveryMonths
            didSave = true
        } catch {
            errorMessage = String(interface: LocalizedStringResource("health.error.save"))
        }
    }
}
