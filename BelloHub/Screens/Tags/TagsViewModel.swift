//
//  TagsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the Client tags screen (6.12): the list with how many clients carry each tag, and add, rename,
/// recolor, reorder and delete. Reads and writes go through `ProfileService`, which owns the tags every screen reads.
@MainActor
@Observable
final class TagsViewModel {
    /// The list as the screen shows it. A copy of `ProfileService.tags` that a drag reorders at once, so the row does
    /// not snap back while the new order is being written; every other change waits for the vault to confirm.
    private(set) var tags: [Tag]
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// The list or the counts could not be read; the screen shows this with a retry.
    private(set) var errorMessage: String?
    /// A change could not be saved; the screen shows it above the list and the list stays as it was.
    private(set) var saveErrorMessage: String?
    private(set) var clientCounts: [UUID: Int] = [:]

    private let profile: ProfileService
    private let clients: (any ClientRepository)?
    private let makeID: @Sendable () -> UUID

    init(
        profile: ProfileService,
        clients: (any ClientRepository)?,
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.profile = profile
        self.clients = clients
        self.makeID = makeID
        self.tags = profile.tags
    }

    // MARK: - Reading

    /// Whether the list is empty and nothing is wrong: the screen shows its empty state with the next action.
    var showsEmptyState: Bool { hasLoaded && errorMessage == nil && tags.isEmpty }

    /// Whether to draw placeholder rows: the first read is running and there is nothing to show yet.
    var showsSkeleton: Bool { isLoading && !hasLoaded && tags.isEmpty }

    /// How many clients carry `tag`, or nil while that is not known.
    func clientCount(for tag: Tag) -> Int? { clientCounts[tag.id] }

    func checkName(_ raw: String, editing id: UUID? = nil) -> TagNameCheck {
        TagRules.check(raw, among: tags, editing: id)
    }

    /// The color a new tag starts with.
    var suggestedColor: TagColor { TagRules.suggestedColor(among: tags) }

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
        do {
            try await profile.reloadTags()
            guard let clients else { throw VaultRepositoryError.unavailable }
            let everyone = try await clients.allClients()
            tags = profile.tags
            clientCounts = TagUsage.counts(tags: tags, clients: everyone)
        } catch {
            errorMessage = String(
                localized: "tags.error.load",
                defaultValue: "We could not read your tags. Check that your iPhone is unlocked and try again."
            )
        }
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }

    // MARK: - Editing

    /// Adds a tag, or applies the new name and color to the one being edited. Returns whether it was saved; a name that
    /// is not accepted returns false without touching anything (the sheet shows why while she types).
    @discardableResult
    func save(name: String, color: TagColor, editing tag: Tag?) async -> Bool {
        let result: Tag?
        if let tag {
            result = TagRules.updating(tag, name: name, color: color, among: tags)
        } else {
            result = TagRules.makeTag(name: name, color: color, among: tags, makeID: makeID)
        }
        guard let result else { return false }
        saveErrorMessage = nil
        do {
            try await profile.saveTag(result)
            tags = profile.tags
            if clientCounts[result.id] == nil { clientCounts[result.id] = 0 }
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    /// Deletes a tag and takes it off every client that has it. Returns whether it was deleted.
    @discardableResult
    func delete(_ tag: Tag) async -> Bool {
        saveErrorMessage = nil
        do {
            try await profile.deleteTag(id: tag.id)
            tags = profile.tags
            clientCounts[tag.id] = nil
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    /// Entry point for the drag handles; `moveAsync` is what tests await.
    func move(from source: IndexSet, to destination: Int) {
        Task { await moveAsync(from: source, to: destination) }
    }

    func moveAsync(from source: IndexSet, to destination: Int) async {
        let before = tags
        let after = TagRules.moving(before, from: source, to: destination)
        let changed = TagRules.changed(from: before, to: after)
        guard !changed.isEmpty else { return }
        tags = after
        saveErrorMessage = nil
        do {
            try await profile.saveTags(changed)
        } catch {
            tags = before
            saveErrorMessage = Self.saveFailure
        }
    }

    private static var saveFailure: String {
        String(
            localized: "tags.error.save",
            defaultValue: "We could not save this change. Check that your iPhone has space and try again."
        )
    }
}
