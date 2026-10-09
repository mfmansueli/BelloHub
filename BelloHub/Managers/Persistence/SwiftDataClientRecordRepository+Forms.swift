//
//  SwiftDataClientRecordRepository+Forms.swift
//  BelloHub
//

import Foundation

extension SwiftDataClientRecordRepository {
    func healthFormTemplates() throws -> [HealthFormTemplate] {
        try values(HealthFormTemplate.self, from: items(kind: .healthFormTemplate)).sorted { $0.version < $1.version }
    }

    func save(_ template: HealthFormTemplate) throws {
        if let stored = try item(kind: .healthFormTemplate, id: template.id) {
            let existing = try value(HealthFormTemplate.self, from: stored)
            guard HealthFormTemplateRules.accepts(template, over: existing) else {
                throw FormTemplateError.versionLocked
            }
        }
        try upsert(template)
        try commit()
    }

    func patchTests(for clientID: UUID) throws -> [PatchTest] {
        try values(PatchTest.self, from: items(kind: .patchTest, ownerID: clientID))
            .sorted { ($0.testedAt, $0.id.uuidString) > ($1.testedAt, $1.id.uuidString) }
    }

    func save(_ patchTest: PatchTest) throws {
        try upsert(patchTest)
        try commit()
    }
}
