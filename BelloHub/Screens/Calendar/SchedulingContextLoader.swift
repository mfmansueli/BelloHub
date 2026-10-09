//
//  SchedulingContextLoader.swift
//  BelloHub
//

import Foundation

/// Reads the data a new or moved visit is checked against, through the Services. The two scheduling ViewModels share
/// it so they read the same things the same way.
@MainActor
struct SchedulingContextLoader {
    let appointments: AppointmentService
    let timeBlocks: TimeBlockService
    let vault: VaultService
    let catalogProvider: any HealthFormCatalogProviding
    let localization: AppLocalization

    /// The visits and blocks that overlap `range`.
    func surroundings(of range: DateInterval) async throws -> (appointments: [Appointment], blocks: [TimeBlock]) {
        async let visits = appointments.appointments(in: range)
        async let blocks = timeBlocks.blocks(in: range)
        return try await (visits, blocks)
    }

    /// Everything for `clientID` on top of the surroundings of `range`. A client's health form or catalog that cannot
    /// be read throws: silently warning less would be the unsafe mistake.
    func load(range: DateInterval, clientID: UUID?) async throws -> SchedulingContext {
        var context = SchedulingContext.empty
        let near = try await surroundings(of: range)
        context.appointments = near.appointments
        context.blocks = near.blocks
        context.catalog = try? catalogProvider.catalog(for: localization)
        guard let clientID else { return context }
        context.clientAppointments = try await appointments.appointments(for: clientID)
        if let repository = vault.repository {
            context.form = SchedulingContext.latest(try await repository.healthForms(for: clientID))
            context.patchTests = try await repository.patchTests(for: clientID)
        }
        return context
    }
}
