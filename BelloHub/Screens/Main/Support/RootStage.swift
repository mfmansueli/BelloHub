//
//  RootStage.swift
//  BelloHub
//

/// Which screen the app is on: the state gate of `RootView` (CLAUDE.md section 2).
enum RootStage: Equatable, Sendable {
    /// The first instant of a launch, before the saved session was read.
    case loading
    case welcome
    case signIn(SignInMode)
    /// Signed in, workspace not set up yet: the onboarding.
    case setup
    case locked
    case app
}
