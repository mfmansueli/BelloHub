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
    /// Stores several tags **together**: reordering changes the `position` of many tags, and a crash must never leave
    /// half of them renumbered.
    func save(_ tags: [Tag]) async throws
    /// Deletes only the tag. Clients that carry its id keep a dangling id, so screens use
    /// `deleteTagRemovingFromClients(id:)`; this is the low-level half of it.
    func deleteTag(id: UUID) async throws
    /// Deletes the tag **and** removes its id from every client that has it, in one write: either both happen or
    /// neither. Clients are never deleted by it, and the registration ledger is untouched (a tag edit is not a
    /// registration). Returns how many clients lost the tag; deleting an id that does not exist returns 0.
    @discardableResult
    func deleteTagRemovingFromClients(id: UUID) async throws -> Int

    func recordTemplate() async throws -> RecordTemplate?
    func save(_ template: RecordTemplate) async throws

    /// Stores the profile, services, tags and record template of a finished setup **together**: either all of it is
    /// saved or none, so a crash never leaves a half-configured workspace that looks complete.
    func saveOnboarding(_ result: OnboardingResult) async throws
}
