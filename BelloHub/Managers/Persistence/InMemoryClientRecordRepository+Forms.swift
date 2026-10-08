//
//  InMemoryClientRecordRepository+Forms.swift
//  BelloHub
//

#if DEBUG
import Foundation

extension InMemoryClientRecordRepository {
    func healthFormTemplates() -> [HealthFormTemplate] {
        healthFormTemplatesByVersion.values.sorted { $0.version < $1.version }
    }

    func save(_ template: HealthFormTemplate) throws {
        guard HealthFormTemplateRules.accepts(template, over: healthFormTemplatesByVersion[template.version]) else {
            throw FormTemplateError.versionLocked
        }
        healthFormTemplatesByVersion[template.version] = template
        changes.notify()
    }

    func patchTests(for clientID: UUID) -> [PatchTest] {
        patchTestsByID.values.filter { $0.clientID == clientID }
            .sorted { ($0.testedAt, $0.id.uuidString) > ($1.testedAt, $1.id.uuidString) }
    }

    func save(_ patchTest: PatchTest) {
        patchTestsByID[patchTest.id] = patchTest
        changes.notify()
    }
}
#endif
