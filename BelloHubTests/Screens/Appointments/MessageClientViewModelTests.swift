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
            setup: store.setup, messages: store.messages, links: store.links, now: { [now = store.now] in now }
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

    // MARK: - The client's own link (mintManageLink)

    private func withSlug(_ store: AppointmentTestStore) async throws {
        var setup = store.setup.setup
        setup.slug = "maria"
        try await store.setup.saveSetup(setup)
    }

    @Test("A visit from the booking page carries the client's own link to change or cancel, on its own line")
    func manageLinkForBookingPageVisit() async throws {
        let store = await AppointmentTestStore()
        try await withSlug(store)
        let visit = await store.save(hoursFromNow: 48, bookingID: "bk-1")
        let model = makeModel(store, visitID: visit.id)

        await model.loadAsync()

        let choice = try #require(model.linkChoice)
        #expect(choice.source == .manageLink)
        let link = try #require(choice.link)
        #expect(link.hasPrefix("https://bellohub.app/m/"))
        #expect(model.text?.contains("\n\(link)") == true)
        #expect(model.text?.contains("bellohub.app/maria") == false)
        #expect(model.showsLinkLine && !model.isPreparingLink)
        #expect(await store.inbox.writes == ["mintManageLink:bk-1"])
    }

    @Test("A visit she added herself carries her booking page, and says why")
    func bookingPageForManualVisit() async throws {
        let store = await AppointmentTestStore()
        try await withSlug(store)
        let visit = await store.save(hoursFromNow: 48)
        let model = makeModel(store, visitID: visit.id)

        await model.loadAsync()

        let expected = ClientLinkChoice(source: .bookingPage(.addedByHand), link: "https://bellohub.app/maria")
        #expect(model.linkChoice == expected)
        #expect(model.text?.contains("\nhttps://bellohub.app/maria") == true)
        #expect(await store.inbox.writes.isEmpty, "no server call for a visit the server does not know")
    }

    @Test("Offline the booking page goes in; pressing Open tries the client's own link again")
    func offlineThenRetryOnOpen() async throws {
        let store = await AppointmentTestStore()
        try await withSlug(store)
        let visit = await store.save(hoursFromNow: 48, bookingID: "bk-1")
        await store.inbox.setWriteFailure(.unreachable)
        let model = makeModel(store, visitID: visit.id)

        await model.loadAsync()
        #expect(model.linkChoice?.source == .bookingPage(.offline))
        #expect(model.text?.contains("https://bellohub.app/maria") == true)

        await store.inbox.setWriteFailure(nil)
        await model.openAsync()

        #expect(model.linkChoice?.source == .manageLink)
        let opened = try #require(store.sender.opened.first?.absoluteString)
        #expect(opened.contains(MessageLinks.encoded("https://bellohub.app/m/")))
    }

    @Test("A server refusal falls back to the booking page as 'could not be prepared'")
    func failedFallsBack() async throws {
        let store = await AppointmentTestStore()
        try await withSlug(store)
        let visit = await store.save(hoursFromNow: 48, bookingID: "bk-1")
        await store.inbox.setWriteFailure(.rejected)
        let model = makeModel(store, visitID: visit.id)

        await model.loadAsync()

        #expect(model.linkChoice == ClientLinkChoice(source: .bookingPage(.failed), link: "https://bellohub.app/maria"))
    }

    @Test("The confirmation carries her saved address on its own lines, with the map link")
    func confirmationCarriesAddress() async throws {
        let store = await AppointmentTestStore()
        var setup = store.setup.setup
        setup.slug = "maria"
        setup.location = BusinessLocation(
            street: "Rua Augusta 1200", postalCode: "01304-001", city: "São Paulo", countryCode: "BR"
        )
        try await store.setup.saveSetup(setup)
        let visit = await store.save(hoursFromNow: 48)
        let model = makeModel(store, visitID: visit.id)

        await model.loadAsync()

        let text = try #require(model.text)
        #expect(text.contains("\nRua Augusta 1200\nSão Paulo 01304-001\nhttps://www.google.com/maps/search/"))
        #expect(!text.contains("{address}"))
    }
}
