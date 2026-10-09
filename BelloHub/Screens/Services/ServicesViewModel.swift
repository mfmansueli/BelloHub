//
//  ServicesViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the Services screen (6.1) and its form (6.2): the list, add, edit, switch on or off, delete and
/// reorder. Every change is written to the vault first and shown after it confirms (CLAUDE.md section 2); a failed
/// write leaves the list as it was and says so, except a drag, which moves at once so the row does not snap back and
/// moves back if the write fails.
@MainActor
@Observable
final class ServicesViewModel {
    private(set) var services: [Service] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// The list could not be read; the screen shows this with a retry.
    private(set) var errorMessage: String?
    /// A change could not be saved; the screen shows it above the list and the list stays as it was.
    private(set) var saveErrorMessage: String?
    /// What the contraindication picker offers, in her language. Empty until `loadContraindicationOptions()` ran.
    private(set) var contraindicationGroups: [ContraindicationGroup] = []

    private let repository: (any ServicesRepository)?
    private let catalogProvider: any HealthFormCatalogProviding
    private let locale: Locale
    private let makeID: @Sendable () -> UUID

    init(
        repository: (any ServicesRepository)?,
        locale: Locale = .current,
        catalogProvider: any HealthFormCatalogProviding = BundleHealthFormCatalogProvider(),
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.locale = locale
        self.catalogProvider = catalogProvider
        self.makeID = makeID
    }

    // MARK: - Reading

    /// Whether the list is empty and nothing is wrong: the screen shows its empty state with the next action.
    var showsEmptyState: Bool { hasLoaded && errorMessage == nil && services.isEmpty }

    /// Whether to draw placeholder rows: the first read is running and there is nothing to show yet.
    var showsSkeleton: Bool { isLoading && !hasLoaded && services.isEmpty }

    /// What the form needs to start a new service: the defaults, and the category most services use.
    func newDraft() -> ServiceDraft {
        var draft = ServiceDraft()
        draft.category = ServiceRules.suggestedCategory(among: services)
        return draft
    }

    func draft(for service: Service) -> ServiceDraft {
        ServiceDraft(service, locale: locale)
    }

    /// The categories the form offers as chips, with the one in the draft.
    func categories(including current: String) -> [String] {
        ServiceRules.categories(among: services, including: current)
    }

    func issues(in draft: ServiceDraft, editing id: UUID?) -> [ServiceFormIssue] {
        ServiceRules.issues(in: draft, among: services, editing: id, locale: locale)
    }

    // MARK: - Loading

    /// Entry point for appearing and retrying; `loadAsync()` is what `.refreshable` awaits.
    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        guard let repository else {
            errorMessage = Self.loadFailure
            return
        }
        do {
            services = ServiceRules.ordered(try await repository.services())
        } catch {
            errorMessage = Self.loadFailure
        }
    }

    /// Reads the health-form catalog once, for the contraindication picker. A catalog that cannot be read leaves the
    /// picker with only "under 18"; the rest of the form still works.
    func loadContraindicationOptions() {
        guard contraindicationGroups.isEmpty else { return }
        let minorGroup = String(localized: "services.contra.group.client", defaultValue: "About the client")
        let minorTitle = String(localized: "services.contra.minor", defaultValue: "Under 18")
        let catalog = try? catalogProvider.catalog(for: AppLocalization(locale: locale))
        contraindicationGroups = catalog.map {
            ContraindicationOptions.groups(in: $0, minorGroupTitle: minorGroup, minorTitle: minorTitle)
        } ?? [ContraindicationGroup(
            id: ContraindicationOptions.aboutTheClientGroupID, title: minorGroup,
            options: [ContraindicationOption(
                token: ContraindicationMatcher.minorToken, title: minorTitle, summary: minorTitle
            )]
        )]
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }

    // MARK: - Editing

    /// Adds a service, or applies the draft to the one being edited. Returns whether it was saved; a draft with an
    /// issue returns false without touching anything (the form shows why while she types).
    @discardableResult
    func save(_ draft: ServiceDraft, editing service: Service?) async -> Bool {
        guard let repository,
              let built = ServiceRules.build(draft, among: services, editing: service, locale: locale, makeID: makeID)
        else { return false }
        saveErrorMessage = nil
        do {
            try await repository.save(built)
            services = ServiceRules.ordered(services.filter { $0.id != built.id } + [built])
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    /// Deletes a service. Appointments that used it keep its name; nothing in a client's record changes. Returns
    /// whether it was deleted.
    @discardableResult
    func delete(_ service: Service) async -> Bool {
        guard let repository else { return false }
        saveErrorMessage = nil
        do {
            try await repository.deleteService(id: service.id)
            services.removeAll { $0.id == service.id }
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    /// Entry point for the swipe action; `setActiveAsync` is what tests await.
    func setActive(_ isActive: Bool, for service: Service) {
        Task { await setActiveAsync(isActive, for: service) }
    }

    func setActiveAsync(_ isActive: Bool, for service: Service) async {
        guard let repository, service.isActive != isActive else { return }
        // Not through the form's build: a switch changes one field and must never be refused over another one (an
        // old duplicate name) or re-read the price through text.
        let changed = ServiceRules.setting(service, active: isActive)
        saveErrorMessage = nil
        do {
            try await repository.save(changed)
            services = ServiceRules.ordered(services.filter { $0.id != changed.id } + [changed])
        } catch {
            saveErrorMessage = Self.saveFailure
        }
    }

    /// Entry point for the drag handles; `moveAsync` is what tests await.
    func move(from source: IndexSet, to destination: Int) {
        Task { await moveAsync(from: source, to: destination) }
    }

    func moveAsync(from source: IndexSet, to destination: Int) async {
        guard let repository else { return }
        let before = services
        let after = PositionRules.moving(before, from: source, to: destination)
        let changed = PositionRules.changed(from: before, to: after)
        guard !changed.isEmpty else { return }
        services = after
        saveErrorMessage = nil
        do {
            try await repository.save(changed)
        } catch {
            services = before
            saveErrorMessage = Self.saveFailure
        }
    }

    // MARK: - Messages

    private static var loadFailure: String {
        String(
            localized: "services.error.load",
            defaultValue: "We could not read your services. Check that your iPhone is unlocked and try again."
        )
    }

    private static var saveFailure: String {
        String(
            localized: "services.error.save",
            defaultValue: "We could not save this change. Check that your iPhone has space and try again."
        )
    }
}
