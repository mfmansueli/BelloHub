//
//  LocalDevAuthProvider.swift
//  BelloHub
//

#if DEBUG
import Foundation
import os

/// Signs in without a server, so the whole app is usable before Firebase exists (S3 to S7) and in UI tests.
/// It accepts one fixed code and remembers the user across launches in `UserDefaults`. DEBUG only: a Release build
/// must never carry a sign-in shortcut.
final class LocalDevAuthProvider: AuthProvider, Sendable {
    /// The code every sign-in accepts.
    static let fixedCode = "123456"

    private let defaults: UserDefaultsBox
    private let pendingPhone = OSAllocatedUnfairLock<String?>(initialState: nil)

    init(defaults: UserDefaults = .standard) {
        self.defaults = UserDefaultsBox(defaults)
    }

    func currentUser() async -> AuthUser? {
        guard let data = defaults.value.data(forKey: DefaultsKey.localDevUser) else { return nil }
        return try? JSONDecoder().decode(AuthUser.self, from: data)
    }

    func requestCode(phoneE164: String) async throws {
        guard phoneE164.hasPrefix("+"), phoneE164.count >= 9 else { throw AuthError.invalidPhone }
        pendingPhone.withLock { $0 = phoneE164 }
    }

    func verify(code: String) async throws -> AuthUser {
        guard let phone = pendingPhone.withLock({ $0 }) else { throw AuthError.invalidCode }
        guard code == Self.fixedCode else { throw AuthError.invalidCode }
        let user = AuthUser(id: "dev-\(phone.dropFirst())", method: .phone, phoneE164: phone)
        defaults.value.set(try? JSONEncoder().encode(user), forKey: DefaultsKey.localDevUser)
        return user
    }

    /// Accepts any credential, so a DEBUG build on a device still works; UI tests use `AppleCredential.devStub`.
    func signInWithApple(_ credential: AppleCredential) async throws -> AuthUser {
        let user = AuthUser(id: "dev-apple-\(credential.userID)", method: .apple, displayName: credential.fullName)
        defaults.value.set(try? JSONEncoder().encode(user), forKey: DefaultsKey.localDevUser)
        return user
    }

    /// A fixed fake token: the DEBUG and UI-test transports never send it anywhere (the live smoke command signs in
    /// with a real dev token instead).
    static let fakeToken = "dev-id-token"

    func idToken() async throws -> String {
        guard await currentUser() != nil else { throw AuthError.unavailable }
        return Self.fakeToken
    }

    func signOut() async throws {
        defaults.value.removeObject(forKey: DefaultsKey.localDevUser)
        pendingPhone.withLock { $0 = nil }
    }
}

/// `UserDefaults` is documented as thread-safe but is not marked `Sendable`; this wrapper says so in one place.
private struct UserDefaultsBox: @unchecked Sendable {
    let value: UserDefaults

    init(_ value: UserDefaults) {
        self.value = value
    }
}
#endif
