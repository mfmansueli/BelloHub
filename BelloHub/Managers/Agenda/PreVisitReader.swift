//
//  PreVisitReader.swift
//  BelloHub
//

import Foundation

/// Reads what the vault holds about one client for the visit's checklist (3.2 and 3.3): her service, health form,
/// consents, patch tests, plans and visits, then hands them to the pure `PreVisitChecklist`. Clinical answers are
/// read here, on the iPhone, and never leave it.
@MainActor
struct PreVisitReader {
    let vault: VaultService
    let catalogProvider: any HealthFormCatalogProviding
    let localization: AppLocalization

    init(
        vault: VaultService, localization: AppLocalization,
        catalogProvider: any HealthFormCatalogProviding = BundleHealthFormCatalogProvider()
    ) {
        self.vault = vault
        self.localization = localization
        self.catalogProvider = catalogProvider
    }

    func checklist(for visit: VisitContext, now: Date, calendar: Calendar) async throws -> PreVisitChecklist {
        guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
        let clientID = visit.client.id
        let services = try await repository.services()
        let templates = try await repository.healthFormTemplates()
        var input = PreVisitChecklist.Input(client: visit.client, appointment: visit.appointment)
        input.service = visit.appointment.serviceID.flatMap { id in services.first { $0.id == id } }
        input.forms = try await repository.healthForms(for: clientID)
        input.consents = try await repository.consents(for: clientID)
        input.patchTests = try await repository.patchTests(for: clientID)
        input.plans = try await repository.sessionPlans(for: clientID)
        input.appointments = try await repository.appointments(for: clientID)
        // A catalog that cannot be read only costs the contraindication wording, never the rest of the checklist.
        input.catalog = try? catalogProvider.catalog(for: localization)
        input.reviewMonths = HealthFormTemplateRules.current(of: templates)?.reviewEveryMonths
            ?? HealthFormTemplateRules.defaultReviewMonths
        return PreVisitChecklist.make(input, now: now, calendar: calendar)
    }
}
