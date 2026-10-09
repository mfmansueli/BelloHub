//
//  AccountViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Account (7.1): her name and business name (saved on Save), the read-only facts (phone,
/// profession, region), sign-out and the delete-account flow with its export-first offer.
@MainActor
@Observable
final class AccountViewModel {
    var displayName: String
    var businessName: String
    private(set) var isSaving = false
    private(set) var saved = false
    private(set) var errorMessage: String?
    private(set) var deletion = AccountDeletionFlow.idle

    let phoneE164: String?
    let userID: String?

    private let profile: ProfileService
    private let account: AccountService
    private let signOut: () -> Void

    init(profile: ProfileService, account: AccountService, session: SessionService, signOut: @escaping () -> Void) {
        self.profile = profile
        self.account = account
        self.signOut = signOut
        displayName = profile.profile?.displayName ?? ""
        businessName = profile.profile?.businessName ?? ""
        phoneE164 = session.user?.phoneE164
        userID = session.user?.id
    }

    // MARK: - Reading

    var stored: ProfessionalProfile? { profile.profile }

    var nameIssue: AccountRules.NameIssue? { AccountRules.nameIssue(displayName) }
    var businessNameIssue: AccountRules.NameIssue? { AccountRules.businessNameIssue(businessName) }

    var canSave: Bool {
        nameIssue == nil && businessNameIssue == nil && !isSaving
            && AccountRules.hasChanges(displayName: displayName, businessName: businessName, profile: stored)
    }

    var isDeleting: Bool { account.isDeleting }
    var deletionErrorMessage: String? { account.errorMessage }

    // MARK: - Saving

    func save() {
        Task { await saveAsync() }
    }

    func saveAsync() async {
        guard canSave, var updated = stored else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        updated.displayName = AccountRules.cleaned(displayName)
        updated.businessName = AccountRules.cleaned(businessName)
        do {
            try await profile.saveProfile(updated)
            displayName = updated.displayName
            businessName = updated.businessName
            saved = true
        } catch {
            errorMessage = String(
                localized: "account.error.save",
                defaultValue: "We could not save your changes. Check that your iPhone has space and try again."
            )
        }
    }

    func dismissSaved() {
        saved = false
    }

    // MARK: - Sign out

    func confirmSignOut() {
        signOut()
    }

    // MARK: - Delete account

    func send(_ event: AccountDeletionFlow.Event) {
        deletion = deletion.next(event)
    }

    /// The last step: the server first, then this iPhone, then the session ends. Only reachable from `.deleting`.
    func deleteAccountAsync(appleAuthorizationCode: String? = nil) async {
        send(.confirmed)
        guard deletion.allowsWipe, let userID else {
            send(.failed)
            return
        }
        let request = AccountDeletionRequest(userID: userID, appleAuthorizationCode: appleAuthorizationCode)
        guard let outcome = await account.deleteAccount(request, confirmed: deletion.allowsWipe) else {
            send(.failed)
            return
        }
        send(.finished(outcome))
    }

    /// After the done screen: the session ends and the app returns to Welcome.
    func leaveAfterDeletion() {
        signOut()
    }
}
