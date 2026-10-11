//
//  AuthProviderFactory.swift
//  BelloHub
//

import Foundation

/// The provider this build signs in with: Firebase (Sign in with Apple) in Release and in DEBUG, so a Debug build on a
/// real iPhone gets a real ID token and the booking link can be published. The development provider (any phone, code
/// 123456, a fake token the server rightly rejects) is only used when a DEBUG launch asks for it with `-devLogin`;
/// UI tests build their own provider and never come through here.
enum AuthProviderFactory {
    static func make(defaults: UserDefaults = .standard) -> any AuthProvider {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-devLogin") {
            return LocalDevAuthProvider(defaults: defaults)
        }
        #endif
        return FirebaseAuthProvider()
    }
}
