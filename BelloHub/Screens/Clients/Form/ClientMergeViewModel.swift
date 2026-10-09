//
//  ClientMergeViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of "Merge with a duplicate" (4.3): pick the other profile of the same person, then combine it
/// into the one being edited. The combining is the repository's (`mergeClient`), which moves everything in one step
/// and never touches the registration ledger. The picker only searches the other clients.
@MainActor
@Observable
final class ClientMergeViewModel {
    let keptID: UUID
    private(set) var kept: Client?
    private(set) var candidates: [Client] = []
    private(set) var isLoading = true
    private(set) var isMerging = false
    private(set) var errorMessage: String?
    /// The merge is done; the screen closes the sheet and the edit screen behind it.
    private(set) var didMerge = false
    var searchText = ""
    /// The profile she tapped, waiting for her confirmation.
    var chosen: Client?

    private let vault: VaultService
    private let profile: ProfileService

    init(keptID: UUID, vault: VaultService, profile: ProfileService) {
        self.keptID = keptID
        self.vault = vault
        self.profile = profile
    }

    // MARK: - Derived

    /// The other profiles matching the search, in reading order.
    var results: [Client] {
        candidates.filter { ClientSearch.matches($0, query: searchText, tags: profile.tags) }
    }

    var hasNoCandidates: Bool { !isLoading && candidates.isEmpty && errorMessage == nil }

    var tagsByID: [UUID: Tag] {
        Dictionary(profile.tags.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Actions

    func load() async {
        guard let repository = vault.repository else { return fail() }
        do {
            let all = try await repository.allClients()
            kept = all.first { $0.id == keptID }
            candidates = ClientSort.sorted(all.filter { $0.id != keptID })
            isLoading = false
            errorMessage = nil
        } catch {
            fail()
        }
    }

    /// Fire-and-forget entry point for the confirmation button (CLAUDE.md section 2).
    func merge(_ other: Client) {
        Task { await mergeAsync(other) }
    }

    func mergeAsync(_ other: Client) async {
        guard !isMerging, let repository = vault.repository else { return }
        isMerging = true
        errorMessage = nil
        defer { isMerging = false }
        do {
            try await repository.mergeClient(keeping: keptID, merging: other.id)
            didMerge = true
        } catch {
            errorMessage = String(localized: "clientMerge.error.merge")
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func fail() {
        isLoading = false
        errorMessage = String(localized: "clientMerge.error.load")
    }
}
