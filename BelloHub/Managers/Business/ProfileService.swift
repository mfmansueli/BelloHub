//
//  ProfileService.swift
//  BelloHub
//

import Foundation
import Observation

/// The signed-in professional's profile and the choices of her setup, loaded from the vault once it is unlocked.
/// Screens read it for her name, her business language and what she calls her clients.
@MainActor
@Observable
final class ProfileService {
    private(set) var profile: ProfessionalProfile?
    private(set) var template: RecordTemplate?
    private(set) var tags: [Tag] = []

    private let vault: VaultService

    init(vault: VaultService) {
        self.vault = vault
    }

    /// What she calls the people she serves; "client" until she chose.
    var clientTerm: ClientTerm { profile?.clientTerm ?? .client }

    /// Reads the profile, the record template and the tags. Call after the vault is unlocked. A failure leaves the
    /// previous values: a locked vault must not blank a screen that is already showing.
    func load() async {
        guard let repository = vault.repository else { return }
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
        guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
        try await repository.saveOnboarding(result)
        profile = result.profile
        template = result.template
        tags = result.tags
    }
}
