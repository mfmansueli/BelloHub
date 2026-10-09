//
//  RunningLateViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RunningLateViewModel")
@MainActor
struct RunningLateViewModelTests {
    private func makeModel(_ store: AppointmentTestStore, visitID: UUID) -> RunningLateViewModel {
        RunningLateViewModel(
            appointmentID: visitID, appointments: store.appointments, vault: store.vault, profile: store.profile,
            setup: store.setup, messages: store.messages, now: { [now = store.now] in now }
        )
    }

    @Test("The recipients are this visit's client and the ones after her that day, in order")
    func listsTheClientsStillWaiting() async {
        let store = await AppointmentTestStore()
        let earlier = await store.save(hoursFromNow: -2)
        let anchor = await store.save(hoursFromNow: 1)
        let later = await store.save(hoursFromNow: 3)
        let cancelled = await store.save(hoursFromNow: 4, status: .cancelled)
        await store.save(hoursFromNow: 26)
        let model = makeModel(store, visitID: anchor.id)

        await model.loadAsync()

        #expect(!model.isLoading)
        #expect(model.recipients.map(\.id) == [anchor.id, later.id])
        #expect(!model.recipients.map(\.id).contains(earlier.id))
        #expect(!model.recipients.map(\.id).contains(cancelled.id))
        #expect(model.recipients.allSatisfy { $0.client.id == store.client.id })
    }

    @Test("Telling a client opens her chat with the delay and remembers it")
    func tellOpensOneChat() async throws {
        let store = await AppointmentTestStore()
        let anchor = await store.save(hoursFromNow: 1)
        let model = makeModel(store, visitID: anchor.id)
        await model.loadAsync()
        model.delay = 20
        let recipient = try #require(model.recipients.first)

        await model.tellAsync(recipient)

        #expect(model.opened == [anchor.id])
        #expect(store.sender.opened.count == 1)
        #expect(model.share == nil)
        #expect(try await store.visit(anchor.id)?.startsAt == anchor.startsAt)
    }

    @Test("Without WhatsApp or Messages the share sheet carries the text, and closing it clears it")
    func fallsBackToShareSheet() async throws {
        let store = await AppointmentTestStore()
        store.sender.whatsAppInstalled = false
        store.sender.messagesAvailable = false
        let anchor = await store.save(hoursFromNow: 1)
        let model = makeModel(store, visitID: anchor.id)
        await model.loadAsync()
        let recipient = try #require(model.recipients.first)

        await model.tellAsync(recipient)

        #expect(model.share?.text.isEmpty == false)
        #expect(model.opened.contains(anchor.id))
        model.dismissShare()
        #expect(model.share == nil)
    }

    @Test("The long-wait hint shows from thirty minutes")
    func longWaitHint() async {
        let store = await AppointmentTestStore()
        let anchor = await store.save(hoursFromNow: 1)
        let model = makeModel(store, visitID: anchor.id)
        #expect(model.delay == RunningLateRules.defaultDelay)
        #expect(!model.showsLongWaitHint)

        model.delay = RunningLateRules.longWaitMinutes

        #expect(model.showsLongWaitHint)
    }

    @Test("An unknown visit says it is missing")
    func missingVisit() async {
        let store = await AppointmentTestStore()
        let model = makeModel(store, visitID: UUID())
        await model.loadAsync()
        #expect(model.isMissing)
        #expect(model.recipients.isEmpty)
    }
}
