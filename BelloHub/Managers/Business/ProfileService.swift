//
//  ProfileService.swift
//  BelloHub
//

import Foundation
import Observation

/// The signed-in professional's profile and the choices of her setup, loaded from the vault once it is unlocked.
/// Screens read it for her name, her business language, what she calls her clients, her tags and the fields of her
/// record. Edits to the tags and the record template go through it, so every screen that reads them updates at once.
///
/// The published values change **only after the vault confirms a write** (CLAUDE.md section 2): a failed save leaves
/// them as they were, and the caller decides what to tell her.
///
/// It needs only the business half of the vault (`BusinessRepository`): the app gives it the vault, and a test can give
/// it a small fake that fails on demand.
@MainActor
@Observable
final class ProfileService {
    private(set) var profile: ProfessionalProfile?
    private(set) var template: RecordTemplate?
    private(set) var tags: [Tag] = []

    /// Looked up on each use, because the vault may be unavailable (nil) when the store could not be opened.
    private let source: @MainActor () -> (any BusinessRepository)?

    init(vault: VaultService) {
        source = { vault.repository }
    }

    init(repository: any BusinessRepository) {
        source = { repository }
    }

    /// What she calls the people she serves; "client" until she chose.
    var clientTerm: ClientTerm { profile?.clientTerm ?? .client }

    /// Reads the profile, the record template and the tags. Call after the vault is unlocked. A failure leaves the
    /// previous values: a locked vault must not blank a screen that is already showing.
    func load() async {
        guard let repository = source() else { return }
        if let loaded = try? await repository.profile() { profile = loaded }
        if let loaded = try? await repository.recordTemplate() { template = loaded }
        if let loaded = try? await repository.tags() { tags = loaded }
    }

    /// Forgets everything (sign-out, lock). The next `load()` starts from the vault again.
    func clear() {
        profile = nil
        template = nil
        tags = []
    }

    /// Stores a finished setup and makes it the current state.
    func saveOnboarding(_ result: OnboardingResult) async throws {
        let repository = try requireRepository()
        try await repository.saveOnboarding(result)
        profile = result.profile
        template = result.template
        tags = result.tags
    }

    // MARK: - Tags

    /// Reads the tags again. A screen calls it when it appears, because another screen (a new client sheet) may have
    /// added one through the repository since. Throws when the vault cannot be read, so the screen can say so.
    func reloadTags() async throws {
        tags = try await requireRepository().tags()
    }

    /// Adds or updates one tag.
    func saveTag(_ tag: Tag) async throws {
        try await requireRepository().save(tag)
        tags = Tag.ordered(tags.filter { $0.id != tag.id } + [tag])
    }

    /// Stores several tags in one write (a new order renumbers many of them).
    func saveTags(_ changed: [Tag]) async throws {
        try await requireRepository().save(changed)
        let changedIDs = Set(changed.map(\.id))
        tags = Tag.ordered(tags.filter { !changedIDs.contains($0.id) } + changed)
    }

    /// Deletes a tag and removes it from every client that has it, in one write. Clients are never deleted. Returns
    /// how many clients lost the tag.
    @discardableResult
    func deleteTag(id: UUID) async throws -> Int {
        let affected = try await requireRepository().deleteTagRemovingFromClients(id: id)
        tags.removeAll { $0.id == id }
        return affected
    }

    // MARK: - Record template

    /// Reads the record template again, for the same reason as `reloadTags()`.
    func reloadTemplate() async throws {
        if let loaded = try await requireRepository().recordTemplate() { template = loaded }
    }

    /// Stores the record template and makes the stored copy (with its new `updatedAt`) the current one.
    func saveTemplate(_ updated: RecordTemplate) async throws {
        let repository = try requireRepository()
        try await repository.save(updated)
        // The repository stamps `updatedAt`; read it back, and keep what was just written if the read fails.
        template = (try? await repository.recordTemplate()) ?? updated
    }

    // MARK: - Helpers

    private func requireRepository() throws -> any BusinessRepository {
        guard let repository = source() else { throw VaultRepositoryError.unavailable }
        return repository
    }
}
