//
//  BusinessRepository.swift
//  BelloHub
//

import Foundation

/// The professional's own setup: her profile, the tags she labels clients with and the fields of her treatment
/// record. Services live in `AgendaRepository` because appointments point at them. Everything here is non-clinical
/// and stored in the clear (docs/05-DATA-MODEL.md section 1).
protocol BusinessRepository: Sendable {
    /// Nil until onboarding finished: the app uses this to tell a new professional from a returning one.
    func profile() async throws -> ProfessionalProfile?
    func save(_ profile: ProfessionalProfile) async throws

    func tags() async throws -> [Tag]
    func save(_ tag: Tag) async throws
    func deleteTag(id: UUID) async throws

    func recordTemplate() async throws -> RecordTemplate?
    func save(_ template: RecordTemplate) async throws

    /// Stores the profile, services, tags and record template of a finished setup **together**: either all of it is
    /// saved or none, so a crash never leaves a half-configured workspace that looks complete.
    func saveOnboarding(_ result: OnboardingResult) async throws
}
