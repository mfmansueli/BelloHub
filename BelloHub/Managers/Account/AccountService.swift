//
//  AccountService.swift
//  BelloHub
//

import Foundation
import Observation

/// Deleting her account (7.1), in the order the plan fixes: export first (the screen offers it), then the cascade.
/// The server is asked first so a failure there never leaves her with an empty iPhone and a live account; then the
/// vault is wiped, the seed leaves the Keychain, the local settings go, and the session ends. The vault is touched
/// **only** after `confirmed` was passed, which the screen sets from the explicit confirmation.
@MainActor
@Observable
final class AccountService {
    private(set) var isDeleting = false
    private(set) var errorMessage: String?

    private let vault: VaultService
    private let keyManager: KeyManager
    private let keyStore: any KeyStoring
    private let deleter: any AccountDeleting
    private let defaults: UserDefaults

    init(
        vault: VaultService,
        keyManager: KeyManager,
        keyStore: any KeyStoring,
        deleter: any AccountDeleting,
        defaults: UserDefaults = .standard
    ) {
        self.vault = vault
        self.keyManager = keyManager
        self.keyStore = keyStore
        self.deleter = deleter
        self.defaults = defaults
    }

    /// Runs the cascade. Returns nil, with `errorMessage` set, when the server refused or the vault could not be
    /// emptied; nothing local is touched before the server answered.
    func deleteAccount(_ request: AccountDeletionRequest, confirmed: Bool) async -> AccountDeletionOutcome? {
        guard confirmed, !isDeleting else { return nil }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            let outcome = try await deleter.deleteAccount(request)
            try await wipeDevice()
            return outcome
        } catch {
            errorMessage = String(
                localized: "account.delete.error",
                defaultValue: "We could not delete your account. Check your connection and try again."
            )
            return nil
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private

    private func wipeDevice() async throws {
        guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
        try await repository.wipeEverything()
        keyManager.lock()
        try keyStore.deleteSeed()
        for key in DefaultsKey.clearedOnAccountDeletion {
            defaults.removeObject(forKey: key)
        }
    }
}
