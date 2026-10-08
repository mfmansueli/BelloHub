//
//  SignInMode.swift
//  BelloHub
//

/// Why she is on the sign-in screen: a new workspace or one she already has. The code and the phone are the same;
/// only the words differ.
enum SignInMode: Equatable, Sendable {
    case create
    case existing
}
