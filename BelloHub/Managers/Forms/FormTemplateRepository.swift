//
//  FormTemplateRepository.swift
//  BelloHub
//

import Foundation

/// The health form the professional asks (every version of it) and the patch-test log of each client. Both live only
/// in the vault (D2); what was tested and how the skin reacted is encrypted by the implementation (D26). Composed into
/// `ClientRecordRepository` like the other focused protocols.
protocol FormTemplateRepository: Sendable {
    /// Every stored version, oldest first. Empty until the first form is filled in or the template is first saved.
    func healthFormTemplates() async throws -> [HealthFormTemplate]

    /// Stores a version. A version that already exists keeps its questions: saving it again with other questions
    /// throws `FormTemplateError.versionLocked`, because forms signed on it refer to them. Changing only "ask again
    /// every" on the current version is allowed.
    func save(_ template: HealthFormTemplate) async throws

    /// A client's patch tests, newest first.
    func patchTests(for clientID: UUID) async throws -> [PatchTest]
    func save(_ patchTest: PatchTest) async throws
}
