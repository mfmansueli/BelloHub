//
//  AddOnsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the Add-ons screen (6.3): the list, add, edit, switch on or off, delete and reorder. Every
/// change is written to the vault first and shown after it confirms (CLAUDE.md section 2); a failed write leaves the
/// list as it was and says so, except a drag, which moves at once and moves back if the write fails.
@MainActor
@Observable
final class AddOnsViewModel {
    private(set) var addOns: [AddOn] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// The list could not be read; the screen shows this with a retry.
    private(set) var errorMessage: String?
    /// A change could not be saved; the screen shows it above the list and the list stays as it was.
    private(set) var saveErrorMessage: String?

    private let repository: (any CatalogRepository)?
    private let locale: Locale
    private let makeID: @Sendable () -> UUID

    init(
        repository: (any CatalogRepository)?, locale: Locale = .current,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.locale = locale
        self.makeID = makeID
    }

    // MARK: - Reading

    /// Whether the list is empty and nothing is wrong: the screen shows its empty state with the next action.
    var showsEmptyState: Bool { hasLoaded && errorMessage == nil && addOns.isEmpty }

    /// Whether to draw placeholder rows: the first read is running and there is nothing to show yet.
    var showsSkeleton: Bool { isLoading && !hasLoaded && addOns.isEmpty }

    /// The add-ons clients can tick, for the "What clients see" card.
    var offered: [AddOn] { AddOnRules.offered(addOns) }

    func draft(for addOn: AddOn?) -> AddOnDraft {
        addOn.map { AddOnDraft($0, locale: locale) } ?? AddOnDraft()
    }

    func issues(in draft: AddOnDraft, editing id: UUID?) -> [AddOnFormIssue] {
        AddOnRules.issues(in: draft, among: addOns, editing: id, locale: locale)
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
            addOns = AddOnRules.ordered(try await repository.addOns())
        } catch {
            errorMessage = Self.loadFailure
        }
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }

    // MARK: - Editing

    /// Adds an add-on, or applies the draft to the one being edited. Returns whether it was saved; a draft with an
    /// issue returns false without touching anything (the form shows why while she types).
    @discardableResult
    func save(_ draft: AddOnDraft, editing addOn: AddOn?) async -> Bool {
        guard let repository,
              let built = AddOnRules.build(draft, among: addOns, editing: addOn, locale: locale, makeID: makeID)
        else { return false }
        saveErrorMessage = nil
        do {
            try await repository.save(built)
            addOns = AddOnRules.ordered(addOns.filter { $0.id != built.id } + [built])
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    /// Deletes an add-on. Returns whether it was deleted.
    @discardableResult
    func delete(_ addOn: AddOn) async -> Bool {
        guard let repository else { return false }
        saveErrorMessage = nil
        do {
            try await repository.deleteAddOn(id: addOn.id)
            addOns.removeAll { $0.id == addOn.id }
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    /// Entry point for the row's switch; `setOfferedAsync` is what tests await.
    func setOffered(_ isOffered: Bool, for addOn: AddOn) {
        Task { await setOfferedAsync(isOffered, for: addOn) }
    }

    func setOfferedAsync(_ isOffered: Bool, for addOn: AddOn) async {
        guard let repository, addOn.isOffered != isOffered else { return }
        let changed = AddOnRules.setting(addOn, offered: isOffered)
        saveErrorMessage = nil
        do {
            try await repository.save(changed)
            addOns = AddOnRules.ordered(addOns.filter { $0.id != changed.id } + [changed])
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
        let before = addOns
        let after = PositionRules.moving(before, from: source, to: destination)
        let changed = PositionRules.changed(from: before, to: after)
        guard !changed.isEmpty else { return }
        addOns = after
        saveErrorMessage = nil
        do {
            try await repository.save(changed)
        } catch {
            addOns = before
            saveErrorMessage = Self.saveFailure
        }
    }

    // MARK: - Messages

    private static var loadFailure: String {
        String(
            localized: "addOns.error.load",
            defaultValue: "We could not read your add-ons. Check that your iPhone is unlocked and try again."
        )
    }

    private static var saveFailure: String {
        String(
            localized: "addOns.error.save",
            defaultValue: "We could not save this change. Check that your iPhone has space and try again."
        )
    }
}
