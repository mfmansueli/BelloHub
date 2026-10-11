//
//  OnboardingProgress.swift
//  BelloHub
//

import Foundation

/// Where she stopped in the setup and what she had chosen, saved after every change so a relaunch (or the app being
/// closed by iOS) brings her back to the same step with the same choices (routine-a item 3). Her name and business
/// name are her own, not client data; nothing clinical is in a draft.
struct OnboardingProgress: Equatable, Codable, Sendable {
    var stepName: String
    var draft: OnboardingDraft

    var step: OnboardingStep {
        OnboardingStep(name: stepName) ?? .about
    }
}
