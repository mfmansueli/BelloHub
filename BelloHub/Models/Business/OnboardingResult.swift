//
//  OnboardingResult.swift
//  BelloHub
//

/// What the setup produces: everything the vault stores at the end of onboarding.
struct OnboardingResult: Equatable, Sendable {
    let profile: ProfessionalProfile
    let services: [Service]
    let tags: [Tag]
    let template: RecordTemplate
}
