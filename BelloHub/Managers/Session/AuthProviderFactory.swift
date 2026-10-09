//
//  AuthProviderFactory.swift
//  BelloHub
//

import Foundation

/// The provider this build signs in with: the development one in DEBUG, Firebase in Release (Apple only until S8
/// adds the phone path).
enum AuthProviderFactory {
    static func make(defaults: UserDefaults = .standard) -> any AuthProvider {
        #if DEBUG
        LocalDevAuthProvider(defaults: defaults)
        #else
        FirebaseAuthProvider()
        #endif
    }
}
