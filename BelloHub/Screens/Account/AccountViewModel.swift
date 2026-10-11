//
//  AccountViewModel.swift
//  BelloHub
//

import AuthenticationServices
import Foundation
import Observation

/// State and actions of Account (7.1): her name and business name (saved on Save), the read-only facts (phone,
/// profession, region), sign-out and the delete-account flow with its export-first offer. A professional who signed
/// in with Apple confirms the deletion with the native Apple button: Apple requires the token to be revoked when the
/// account goes (D44), and only a fresh authorization code can do that, so it is read at that moment and never
/// stored. The VM imports `AuthenticationServices` only for the request and result types of that button, like
/// `AppleSignInViewModel`; the credential itself comes through `AppleCredentialProviding`.
@MainActor
@Observable
final class AccountViewModel {
    var displayName: String
    var businessName: String
    private(set) var isSaving = false
    private(set) var saved = false
    private(set) var errorMessage: String?
    private(set) var deletion = AccountDeletionFlow.idle
    /// Apple did not confirm her (a failure, or an authorization without a code). A cancelled sheet leaves nothing.
    private(set) var appleErrorMessage: String?
    /// The booking link was just copied (long press on its row); the row says so for a moment.
    private(set) var copiedLink = false

    let phoneE164: String?
    let userID: String?
    let signInMethod: SignInMethod?

    private let profile: ProfileService
    private let account: AccountService
    private let credentials: any AppleCredentialProviding
    private let clipboard: any ClipboardWriting
    private let copiedDuration: Duration
    private var copiedTask: Task<Void, Never>?
    private let signOut: () -> Void

    init(
        profile: ProfileService,
        account: AccountService,
        session: SessionService,
        credentials: any AppleCredentialProviding = SystemAppleCredentialProvider(),
        clipboard: any ClipboardWriting = SystemClipboard(),
        copiedDuration: Duration = .seconds(2),
        signOut: @escaping () -> Void
    ) {
        self.profile = profile
        self.account = account
        self.credentials = credentials
        self.clipboard = clipboard
        self.copiedDuration = copiedDuration
        self.signOut = signOut
        displayName = profile.profile?.displayName ?? ""
        businessName = profile.profile?.businessName ?? ""
        phoneE164 = session.user?.phoneE164
        userID = session.user?.id
        signInMethod = session.user?.method
    }

    // MARK: - Booking link

    /// Puts her booking link on the clipboard, the full address a client can open, and says "Copied" for a moment.
    func copyBookingLink(_ link: BookingLink) {
        clipboard.write(link.url.absoluteString)
        copiedLink = true
        copiedTask?.cancel()
        copiedTask = Task { [copiedDuration] in
            try? await Task.sleep(for: copiedDuration)
            guard !Task.isCancelled else { return }
            copiedLink = false
        }
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

    /// An Apple account is deleted through the Apple button (a fresh authorization code revokes the token, D44); a
    /// phone account through the plain destructive button.
    var requiresAppleReauthorization: Bool { signInMethod == .apple }

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
            errorMessage = String(interface: LocalizedStringResource(
                "account.error.save",
                defaultValue: "We could not save your changes. Check that your iPhone has space and try again."
            ))
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
        if event == .cancelled { appleErrorMessage = nil }
    }

    /// The last step: the server first, then this iPhone, then the session ends. Only reachable from `.deleting`.
    /// An Apple account without a fresh code never reaches the server: the token could not be revoked.
    func deleteAccountAsync(appleAuthorizationCode: String? = nil) async {
        if requiresAppleReauthorization && appleAuthorizationCode == nil {
            appleErrorMessage = Self.appleFailedMessage
            return
        }
        appleErrorMessage = nil
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

    // MARK: - Apple re-authorization

    /// The Apple button is about to show its sheet: a fresh nonce goes into the request, the last message goes.
    func prepareAppleReauthorization(_ request: ASAuthorizationAppleIDRequest) {
        appleErrorMessage = nil
        credentials.prepare(request)
    }

    /// Fire-and-forget entry point for the button's completion (CLAUDE.md section 2).
    func completeAppleReauthorization(_ result: Result<ASAuthorization, any Error>) {
        Task { await completeAppleReauthorizationAsync(result) }
    }

    func completeAppleReauthorizationAsync(_ result: Result<ASAuthorization, any Error>) async {
        guard !isDeleting else { return }
        do {
            let credential = try credentials.credential(from: result)
            await deleteAfterAppleReauthorization(with: credential)
        } catch {
            let mapped = AppleSignInErrorMapper.map(error)
            appleErrorMessage = mapped == .cancelled ? nil : Self.appleFailedMessage
        }
    }

    /// Deletes with the code Apple just issued. Also the seam the tests use, since a test cannot build the system's
    /// `ASAuthorization`. The code is single-use and expires in minutes, so it goes straight to the server.
    func deleteAfterAppleReauthorization(with credential: AppleCredential) async {
        guard let code = credential.authorizationCode, !code.isEmpty else {
            appleErrorMessage = Self.appleFailedMessage
            return
        }
        await deleteAccountAsync(appleAuthorizationCode: code)
    }

    #if DEBUG
    /// UI tests cannot drive the Apple sheet: the overlay over the button calls this with the fixed dev credential.
    func deleteWithDevStub() {
        Task { await deleteAfterAppleReauthorization(with: .devStub) }
    }
    #endif

    private static var appleFailedMessage: String {
        String(interface: LocalizedStringResource(
            "account.delete.apple.error", defaultValue: "Apple could not confirm it was you. Try again."
        ))
    }
}
