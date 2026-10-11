//
//  FakeBusinessRepository.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// The business half of the vault in memory, for tests of `ProfileService` and the ViewModels above it. Unlike the
/// real repositories it can be told to fail every write, which is how the error paths are tested. Deleting a tag does
/// not touch clients (it has none); the contract tests cover that against the real implementations.
actor FakeBusinessRepository: BusinessRepository {
    struct WriteFailure: Error, Equatable {}

    private var storedProfile: ProfessionalProfile?
    private var tagsByID: [UUID: Tag] = [:]
    private var storedTemplate: RecordTemplate?
    private var failsWrites = false
    private(set) var writeCount = 0

    /// While true, every write throws `WriteFailure` and changes nothing.
    func setFailsWrites(_ value: Bool) {
        failsWrites = value
    }

    /// Puts a finished setup in, as if onboarding had run, without counting it as a write.
    func seed(_ result: OnboardingResult) {
        storedProfile = result.profile
        storedTemplate = result.template
        result.tags.forEach { tagsByID[$0.id] = $0 }
    }

    /// Replaces the stored template as if another device had saved it, without counting it as a write.
    func seedTemplate(_ template: RecordTemplate) {
        storedTemplate = template
    }

    func storedTags() -> [Tag] {
        Tag.ordered(Array(tagsByID.values))
    }

    func storedRecordTemplate() -> RecordTemplate? {
        storedTemplate
    }

    // MARK: - BusinessRepository

    func profile() -> ProfessionalProfile? {
        storedProfile
    }

    func save(_ profile: ProfessionalProfile) throws {
        try beginWrite()
        storedProfile = profile
    }

    func tags() -> [Tag] {
        storedTags()
    }

    func save(_ tag: Tag) throws {
        try beginWrite()
        tagsByID[tag.id] = tag
    }

    func save(_ tags: [Tag]) throws {
        try beginWrite()
        tags.forEach { tagsByID[$0.id] = $0 }
    }

    func deleteTag(id: UUID) throws {
        try beginWrite()
        tagsByID[id] = nil
    }

    func deleteTagRemovingFromClients(id: UUID) throws -> Int {
        try beginWrite()
        tagsByID[id] = nil
        return 0
    }

    func recordTemplate() -> RecordTemplate? {
        storedTemplate
    }

    func save(_ template: RecordTemplate) throws {
        try beginWrite()
        storedTemplate = template
    }

    func saveOnboarding(_ result: OnboardingResult) throws {
        try beginWrite()
        seed(result)
    }

    private func beginWrite() throws {
        if failsWrites { throw WriteFailure() }
        writeCount += 1
    }
}
