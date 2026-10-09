//
//  BeforeYouStartViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BeforeYouStartViewModel")
@MainActor
struct BeforeYouStartViewModelTests {
    private func makeModel(
        _ store: AppointmentTestStore, visitID: UUID, catalog: FakeHealthFormCatalogProvider = .init()
    ) -> BeforeYouStartViewModel {
        BeforeYouStartViewModel(
            appointmentID: visitID, appointments: store.appointments, vault: store.vault, profile: store.profile,
            catalogProvider: catalog, now: { [now = store.now] in now }
        )
    }

    @Test("The glance is built for the visit, and a visit in progress can be marked completed")
    func loadsTheChecklistForAVisitInProgress() async throws {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: -0.5)
        let model = makeModel(store, visitID: visit.id)

        await model.loadAsync()

        #expect(!model.isLoading)
        #expect(model.visit?.appointment.id == visit.id)
        #expect(model.visit?.client.id == store.client.id)
        #expect(model.checklist != nil)
        #expect(model.canComplete)

        await model.completeAsync()

        #expect(model.didComplete)
        #expect(model.actionErrorMessage == nil)
        #expect(try await store.visit(visit.id)?.status == .completed)
    }

    @Test("A visit that has not started yet cannot be marked completed from the sheet")
    func upcomingVisitCannotBeCompleted() async throws {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: 48)
        let model = makeModel(store, visitID: visit.id)
        await model.loadAsync()
        #expect(!model.canComplete)

        await model.completeAsync()

        #expect(!model.didComplete)
        #expect(try await store.visit(visit.id)?.status == .booked)
    }

    @Test("A missing health form catalog does not block the glance")
    func catalogFailureStillLoads() async {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: 2)
        let model = makeModel(store, visitID: visit.id, catalog: FakeHealthFormCatalogProvider(fails: true))

        await model.loadAsync()

        #expect(!model.isLoading)
        #expect(model.visit != nil)
        #expect(model.checklist != nil)
        #expect(model.errorMessage == nil)
    }

    @Test("An unknown visit says it is missing")
    func missingVisit() async {
        let store = await AppointmentTestStore()
        let model = makeModel(store, visitID: UUID())
        await model.loadAsync()
        #expect(model.isMissing)
        #expect(!model.canComplete)
    }
}
