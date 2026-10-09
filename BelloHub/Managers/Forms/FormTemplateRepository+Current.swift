//
//  FormTemplateRepository+Current.swift
//  BelloHub
//

import Foundation

extension FormTemplateRepository {
    /// The template the professional asks today. A professional who never edited the form has none stored, so the
    /// default for her professions is made and **stored as version 1 at once**: a form signed on it must be able to
    /// find the questions it was signed against later, even after she edits them.
    func currentHealthFormTemplate(
        catalog: HealthFormCatalog, professions: [ProfessionID], now: Date
    ) async throws -> HealthFormTemplate {
        let stored = try await healthFormTemplates()
        if let current = HealthFormTemplateRules.current(of: stored) { return current }
        let created = HealthFormTemplateRules.defaultTemplate(in: catalog, for: professions, now: now)
        try await save(created)
        return created
    }
}
