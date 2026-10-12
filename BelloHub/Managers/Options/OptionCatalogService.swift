//
//  OptionCatalogService.swift
//  BelloHub
//

import Foundation
import Observation

/// The options she saved to reuse, per list (`OptionContext`), shared by every screen that offers them: the visit
/// form, what she knows about a client and Personalization. Adding the same name twice (spaces and letter case
/// aside) returns the existing option, and brings it back if it was archived, so a list never holds duplicates.
/// Nothing is ever deleted: archiving hides an option from the suggestions and keeps every text written with it.
@MainActor
@Observable
final class OptionCatalogService {
    enum Problem: Error, Equatable {
        case empty
        case tooLong
        /// Another option of the same list already has this name.
        case duplicate(existing: String)
    }

    private(set) var options: [SavedOption] = []
    private(set) var hasLoaded = false

    private let vault: VaultService
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID

    init(vault: VaultService, now: @escaping @Sendable () -> Date = { Date() },
         makeID: @escaping @Sendable () -> UUID = { UUID() }) {
        self.vault = vault
        self.now = now
        self.makeID = makeID
    }

    // MARK: - Reading

    /// Loads once per session; safe to call from every screen that needs suggestions.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        guard let repository = vault.repository else { return }
        options = (try? await repository.savedOptions()) ?? options
        hasLoaded = true
    }

    /// Forgets everything (sign-out, lock).
    func clear() {
        options = []
        hasLoaded = false
    }

    /// The options of one list in her order, archived ones last when asked for.
    func options(in context: OptionContext, includingArchived: Bool = false) -> [SavedOption] {
        options
            .filter { $0.context == context && (includingArchived || !$0.isArchived) }
            .sorted { ($0.isArchived ? 1 : 0, $0.position) < ($1.isArchived ? 1 : 0, $1.position) }
    }

    /// The names offered in one list, in her order.
    func names(in context: OptionContext) -> [String] {
        options(in: context).map(\.name)
    }

    // MARK: - Changes

    /// Saves a new option, or returns the one that already has this name (restoring it if archived).
    @discardableResult
    func add(_ name: String, to context: OptionContext) async throws -> SavedOption {
        let cleaned = try validated(name)
        let all = options(in: context, includingArchived: true)
        if let same = all.first(where: { OptionNameRules.key($0.name) == OptionNameRules.key(cleaned) }) {
            guard same.isArchived else { return same }
            var restored = same
            restored.isArchived = false
            try await store([restored])
            return restored
        }
        let option = SavedOption(id: makeID(), context: context, name: cleaned,
                                 position: PositionRules.next(after: all), createdAt: now())
        try await store([option])
        return option
    }

    /// Renames an option. Texts already written keep the old words: records hold text, not options.
    func rename(_ id: UUID, to name: String) async throws {
        guard var option = options.first(where: { $0.id == id }) else { return }
        let cleaned = try validated(name)
        let others = options(in: option.context, includingArchived: true).filter { $0.id != id }.map(\.name)
        if let existing = OptionNameRules.match(cleaned, in: others) { throw Problem.duplicate(existing: existing) }
        option.name = cleaned
        try await store([option])
    }

    func setArchived(_ id: UUID, _ isArchived: Bool) async throws {
        guard var option = options.first(where: { $0.id == id }), option.isArchived != isArchived else { return }
        option.isArchived = isArchived
        try await store([option])
    }

    /// A drag in one list; only what changed is written, in one save.
    func move(in context: OptionContext, from source: IndexSet, to destination: Int) async throws {
        let before = options(in: context)
        let after = PositionRules.moving(before, from: source, to: destination)
        try await store(PositionRules.changed(from: before, to: after))
    }

    // MARK: - Private

    private func validated(_ name: String) throws -> String {
        let cleaned = OptionNameRules.normalized(name)
        guard !cleaned.isEmpty else { throw Problem.empty }
        guard cleaned.count <= OptionNameRules.maxLength else { throw Problem.tooLong }
        return cleaned
    }

    /// Writes first, then updates the list: the screen never shows something the vault refused.
    private func store(_ changed: [SavedOption]) async throws {
        guard !changed.isEmpty else { return }
        guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
        try await repository.save(changed)
        for option in changed {
            if let index = options.firstIndex(where: { $0.id == option.id }) {
                options[index] = option
            } else {
                options.append(option)
            }
        }
    }
}
