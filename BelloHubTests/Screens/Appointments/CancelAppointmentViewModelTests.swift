//
//  CancelAppointmentViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CancelAppointmentViewModel")
@MainActor
struct CancelAppointmentViewModelTests {
    private func makeModel(_ store: AppointmentTestStore, visitID: UUID) -> CancelAppointmentViewModel {
        CancelAppointmentViewModel(
            appointmentID: visitID, appointments: store.appointments, vault: store.vault, profile: store.profile,
            setup: store.setup, messages: store.messages, now: { [now = store.now] in now }
        )
    }

    @Test("Cancelling by the professional saves the cancellation and opens the apology")
    func professionalCancelsWithMessage() async throws {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: 48)
        let model = makeModel(store, visitID: visit.id)
        await model.loadAsync()
        #expect(model.canCancel)
        #expect(model.offersMessage)
        #expect(model.messagePreview?.isEmpty == false)

        await model.confirmAsync()

        let saved = try await store.visit(visit.id)
        #expect(saved?.status == .cancelled)
        #expect(saved?.cancelledBy == .professional)
        #expect(model.done?.message == .opened(.whatsapp))
        #expect(store.sender.opened.count == 1)
        #expect(!model.canCancel)
    }

    @Test("When the client cancelled there is no message, and a last-minute call is a late cancellation")
    func clientCancelsLate() async throws {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: 1)
        let model = makeModel(store, visitID: visit.id)
        await model.loadAsync()
        model.cancelledBy = .client
        #expect(!model.offersMessage)
        #expect(model.notice != nil)

        await model.confirmAsync()

        let saved = try await store.visit(visit.id)
        #expect(saved?.cancelledBy == .client)
        #expect(saved?.isLateCancellation == true)
        #expect(model.done?.message == nil)
        #expect(store.sender.opened.isEmpty)
    }

    @Test("She can keep the cancellation silent")
    func professionalCancelsSilently() async throws {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: 48)
        let model = makeModel(store, visitID: visit.id)
        await model.loadAsync()
        model.sendsMessage = false

        await model.confirmAsync()

        #expect(model.done == Done(message: nil))
        #expect(store.sender.opened.isEmpty)
    }

    @Test("A visit that no longer holds its time cannot be cancelled")
    func completedCannotBeCancelled() async throws {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: -30, status: .completed)
        let model = makeModel(store, visitID: visit.id)
        await model.loadAsync()
        #expect(!model.canCancel)

        await model.confirmAsync()

        #expect(model.done == nil)
        #expect(try await store.visit(visit.id)?.status == .completed)
    }

    @Test("An unknown visit says it is missing")
    func missingVisit() async {
        let store = await AppointmentTestStore()
        let model = makeModel(store, visitID: UUID())
        await model.loadAsync()
        #expect(model.isMissing)
        #expect(!model.isLoading)
        #expect(!model.canCancel)
    }

    private typealias Done = CancelAppointmentViewModel.Done
}
