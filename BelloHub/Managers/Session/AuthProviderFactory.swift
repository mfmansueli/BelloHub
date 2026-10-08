//
//  AuthProviderFactory.swift
//  BelloHub
//

import Foundation

/// The provider this build signs in with: the development one in DEBUG, none in Release until S8 adds Firebase.
enum AuthProviderFactory {
    static func make(defaults: UserDefaults = .standard) -> any AuthProvider {
        #if DEBUG
        LocalDevAuthProvider(defaults: defaults)
        #else
        UnconfiguredAuthProvider()
        #endif
    }
}
