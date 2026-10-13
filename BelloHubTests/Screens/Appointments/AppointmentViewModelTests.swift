//
//  AppointmentViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AppointmentViewModel")
@MainActor
struct AppointmentViewModelTests {
    private func makeModel(_ store: AppointmentTestStore, visitID: UUID) -> AppointmentViewModel {
        AppointmentViewModel(
            appointmentID: visitID, appointments: store.appointments, vault: store.vault, profile: store.profile,
            setup: store.setup, catalogProvider: FakeHealthFormCatalogProvider(), now: { [now = store.now] in now }
        )
    }

    @Test("The detail loads the visit, its glance, the client's no-show standing and the actions for the moment")
    func loadsAnUpcomingVisit() async {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: 48)
        let model = makeModel(store, visitID: visit.id)

        await model.refreshAsync()

        #expect(!model.isLoading)
        #expect(model.visit?.appointment.id == visit.id)
        #expect(model.checklist != nil)
        #expect(model.noShow?.counted == 0)
        #expect(model.layout?.primary == .beforeYouStart)
        #expect(model.reminder == .notSent)
        #expect(!model.showsNoShowHistory)
    }

    @Test("A visit whose time has passed is completed from the detail")
    func completesAPastVisit() async throws {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: -3)
        let model = makeModel(store, visitID: visit.id)
        await model.refreshAsync()
        #expect(model.layout?.primary == .complete)

        await model.completeAsync()

        #expect(model.actionErrorMessage == nil)
        #expect(model.visit?.appointment.status == .completed)
        #expect(try await store.visit(visit.id)?.status == .completed)
        #expect(model.layout?.primary == .registerVisit)
    }

    @Test("An upcoming visit cannot be completed early")
    func upcomingVisitIsNotCompleted() async throws {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: 48)
        let model = makeModel(store, visitID: visit.id)
        await model.refreshAsync()

        await model.completeAsync()

        #expect(try await store.visit(visit.id)?.status == .booked)
    }

    @Test("The history row shows when she missed this visit or has misses counting")
    func showsNoShowHistoryWhenThereIsSomethingToSee() async {
        let store = await AppointmentTestStore()
        await store.save(hoursFromNow: -24 * 10, status: .noShow)
        let visit = await store.save(hoursFromNow: 48)
        let model = makeModel(store, visitID: visit.id)

        await model.refreshAsync()

        #expect(model.noShow?.counted == 1)
        #expect(model.showsNoShowHistory)
    }

    @Test("An unknown visit says it is missing")
    func missingVisit() async {
        let store = await AppointmentTestStore()
        let model = makeModel(store, visitID: UUID())
        await model.refreshAsync()
        #expect(model.isMissing)
        #expect(model.visit == nil)
        #expect(model.layout == nil)
    }
}
