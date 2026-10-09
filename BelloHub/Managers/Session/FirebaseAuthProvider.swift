//
//  FirebaseAuthProvider.swift
//  BelloHub
//

import FirebaseAuth
import Foundation

/// The Release provider: Firebase Auth links the Apple identity as the owner account (D44). This file and the
/// `SessionService` that holds it are the only places that read the auth SDK. The phone path arrives with S8, so it
/// answers `unavailable` here.
///
/// Not exercised against the live project from tests (that needs a real Apple sheet and the Apple provider enabled in
/// the Firebase console); the flow above it is covered through the protocol with fakes.
struct FirebaseAuthProvider: AuthProvider {
    func currentUser() async -> AuthUser? {
        Auth.auth().currentUser.map { Self.authUser(from: $0) }
    }

    func requestCode(phoneE164: String) async throws {
        throw AuthError.unavailable
    }

    func verify(code: String) async throws -> AuthUser {
        throw AuthError.unavailable
    }

    func signInWithApple(_ credential: AppleCredential) async throws -> AuthUser {
        var name = PersonNameComponents()
        name.givenName = credential.givenName
        name.familyName = credential.familyName
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: credential.identityToken, rawNonce: credential.rawNonce, fullName: name
        )
        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            return Self.authUser(from: result.user, fallbackName: credential.fullName)
        } catch {
            throw Self.map(error)
        }
    }

    func signOut() async throws {
        try Auth.auth().signOut()
    }

    // MARK: - Mapping

    private static func authUser(from user: User, fallbackName: String? = nil) -> AuthUser {
        let isApple = user.providerData.contains { $0.providerID == "apple.com" }
        return AuthUser(
            id: user.uid, method: isApple ? .apple : .phone, phoneE164: user.phoneNumber,
            displayName: user.displayName ?? fallbackName
        )
    }

    private static func map(_ error: any Error) -> AuthError {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) else {
            return .appleFailed
        }
        switch code {
        case .networkError: return .network
        case .tooManyRequests: return .tooManyAttempts
        case .operationNotAllowed: return .unavailable
        default: return .appleFailed
        }
    }
}
