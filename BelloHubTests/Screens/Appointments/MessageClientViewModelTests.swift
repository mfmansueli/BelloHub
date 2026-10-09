//
//  MessageClientViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("MessageClientViewModel")
@MainActor
struct MessageClientViewModelTests {
    private func makeModel(_ store: AppointmentTestStore, visitID: UUID) -> MessageClientViewModel {
        MessageClientViewModel(
            appointmentID: visitID, appointments: store.appointments, vault: store.vault, profile: store.profile,
            setup: store.setup, messages: store.messages, now: { [now = store.now] in now }
        )
    }

    @Test("An upcoming visit suggests the confirmation, filled in with her name")
    func suggestsConfirmForUpcomingVisit() async {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: 48)
        let model = makeModel(store, visitID: visit.id)

        await model.loadAsync()

        #expect(!model.isLoading)
        #expect(model.replies.count == BuiltInQuickReply.allCases.count)
        #expect(model.selectedReply?.builtIn == .confirm)
        #expect(model.hasNumber)
        #expect(model.text?.contains("Beatriz") == true)
    }

    @Test("Opening the confirmation marks the reminder as opened on the visit")
    func openingConfirmMarksReminder() async throws {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: 48)
        let model = makeModel(store, visitID: visit.id)
        await model.loadAsync()

        await model.openAsync()

        #expect(model.outcome == .opened(.whatsapp))
        #expect(store.sender.opened.count == 1)
        #expect(try await store.visit(visit.id)?.reminderSentAt == store.now)
    }

    @Test("Picking another reply changes the text and does not touch the reminder")
    func selectingAnotherReply() async throws {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: 48)
        let model = makeModel(store, visitID: visit.id)
        await model.loadAsync()
        let confirmText = model.text
        let aftercare = try #require(model.replies.first { $0.builtIn == .aftercare })

        model.select(aftercare)
        await model.openAsync()

        #expect(model.selectedReply == aftercare)
        #expect(model.text?.isEmpty == false)
        #expect(model.text != confirmText)
        #expect(try await store.visit(visit.id)?.reminderSentAt == nil)
    }

    @Test("Without WhatsApp or Messages the share sheet takes the text, and closing it clears the outcome")
    func fallsBackToShareSheet() async {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: 48)
        store.sender.whatsAppInstalled = false
        store.sender.messagesAvailable = false
        let model = makeModel(store, visitID: visit.id)
        await model.loadAsync()

        await model.openAsync()

        guard case .needsShareSheet(let text)? = model.outcome else {
            Issue.record("expected the share sheet, got \(String(describing: model.outcome))")
            return
        }
        #expect(text == model.text)
        model.dismissShare()
        #expect(model.outcome == nil)
    }

    @Test("A finished visit suggests the aftercare message")
    func suggestsAftercareAfterCompletion() async {
        let store = await AppointmentTestStore()
        let visit = await store.save(hoursFromNow: -30, status: .completed)
        let model = makeModel(store, visitID: visit.id)

        await model.loadAsync()

        #expect(model.selectedReply?.builtIn == .aftercare)
    }

    @Test("An unknown visit says it is missing")
    func missingVisit() async {
        let store = await AppointmentTestStore()
        let model = makeModel(store, visitID: UUID())
        await model.loadAsync()
        #expect(model.isMissing)
        #expect(model.text == nil)
    }
}
