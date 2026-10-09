//
//  AppleSignInErrorMapper.swift
//  BelloHub
//

import AuthenticationServices
import Foundation

/// Maps what `AuthenticationServices` throws to the app's `AuthError`. Closing the Apple sheet is a choice, not a
/// failure, so it becomes `.cancelled` and the screen shows nothing.
enum AppleSignInErrorMapper {
    static func map(_ error: any Error) -> AuthError {
        if let known = error as? AuthError { return known }
        if let apple = error as? ASAuthorizationError {
            return apple.code == .canceled ? .cancelled : .appleFailed
        }
        if error is URLError { return .network }
        return .appleFailed
    }
}
