//
//  AppleSignInViewModel.swift
//  BelloHub
//

import AuthenticationServices
import Foundation
import Observation

/// State and actions of the Sign in with Apple button, shared by Welcome and SignIn. It never touches the auth SDK:
/// `SessionService` does. Closing the Apple sheet is not an error, so it leaves no message.
@MainActor
@Observable
final class AppleSignInViewModel {
    private(set) var isWorking = false
    private(set) var error: AuthError?

    private let session: SessionService
    private let credentials: any AppleCredentialProviding
    private let onSignedIn: @MainActor () async -> Void

    init(
        session: SessionService,
        credentials: any AppleCredentialProviding = SystemAppleCredentialProvider(),
        onSignedIn: @escaping @MainActor () async -> Void
    ) {
        self.session = session
        self.credentials = credentials
        self.onSignedIn = onSignedIn
    }

    // MARK: - Button

    /// The button is about to show the Apple sheet: clears the last message and fills the request.
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        error = nil
        credentials.prepare(request)
    }

    /// Fire-and-forget entry point for the button's completion (CLAUDE.md section 2).
    func complete(_ result: Result<ASAuthorization, any Error>) {
        Task { await completeAsync(result) }
    }

    func completeAsync(_ result: Result<ASAuthorization, any Error>) async {
        guard !isWorking else { return }
        do {
            let credential = try credentials.credential(from: result)
            await signInAsync(with: credential)
        } catch {
            fail(with: error)
        }
    }

    #if DEBUG
    /// UI tests cannot drive the Apple sheet: the button calls this instead, and `LocalDevAuthProvider` signs the
    /// fixed dev Apple user in with no UI.
    func signInWithDevStub() {
        Task { await signInAsync(with: .devStub) }
    }
    #endif

    /// Signs in with a credential already read from Apple. Also the seam the tests use, since a test cannot build the
    /// system's `ASAuthorization`.
    func signInAsync(with credential: AppleCredential) async {
        guard !isWorking else { return }
        isWorking = true
        error = nil
        do {
            try await session.signInWithApple(credential)
            isWorking = false
            await onSignedIn()
        } catch {
            isWorking = false
            fail(with: error)
        }
    }

    // MARK: - Private

    private func fail(with thrown: any Error) {
        let mapped = AppleSignInErrorMapper.map(thrown)
        error = mapped == .cancelled ? nil : mapped
    }
}
