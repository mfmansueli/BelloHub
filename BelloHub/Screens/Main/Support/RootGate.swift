//
//  RootGate.swift
//  BelloHub
//

/// The one rule that decides which screen is shown: signed out goes to welcome or sign-in, signed in without a setup
/// goes to the onboarding, a set-up workspace is locked or open. Pure, so every combination is tested.
enum RootGate {
    static func stage(
        sessionState: SessionService.State,
        hasCompletedSetup: Bool,
        isLocked: Bool,
        signInMode: SignInMode?
    ) -> RootStage {
        switch sessionState {
        case .unknown:
            return .loading
        case .signedOut:
            return signInMode.map(RootStage.signIn) ?? .welcome
        case .signedIn:
            guard hasCompletedSetup else { return .setup }
            return isLocked ? .locked : .app
        }
    }
}
