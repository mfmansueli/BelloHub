//
//  ClientMessageViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ClientMessageViewModel")
@MainActor
struct ClientMessageViewModelTests {
    private struct Rig {
        let model: ClientMessageViewModel
        let messages: MessageService
        let sender: FakeMessageSender
        let world: CalendarWorld
    }

    private func makeRig(
        kind: ClientMessageRequest.Kind = .winBack, client: Client? = nil, sender: FakeMessageSender = FakeMessageSender()
    ) async throws -> Rig {
        let world = try await CalendarWorld.make()
        let target = client ?? world.ana
        let messages = MessageService(vault: world.vault, sender: sender)
        let model = ClientMessageViewModel(
            request: ClientMessageRequest(clientID: target.id, kind: kind), appointments: world.appointments,
            vault: world.vault, profile: world.profile, setup: world.bookingSetup, messages: messages,
            now: { TestClock.now }
        )
        return Rig(model: model, messages: messages, sender: sender, world: world)
    }

    @Test("It loads the client and prepares the text from her last visit")
    func loads() async throws {
        let rig = try await makeRig()
        try await rig.world.appointments.book(
            makeVisit(clientID: rig.world.ana.id, start: TestClock.days(-90), status: .completed, serviceName: "Peeling")
        )

        await rig.model.loadAsync()

        #expect(rig.model.client?.name == "Ana Costa")
        #expect(rig.model.draft.contains("Hi Ana"))
        #expect(rig.model.draft.contains("Peeling"))
        #expect(!rig.model.isLoading && rig.model.errorMessage == nil)
        #expect(rig.model.hasNumber && rig.model.canOpen)
    }

    @Test("Opening sends what she wrote, not the prepared text, and logs only the kind")
    func opensTheEditedText() async throws {
        let rig = try await makeRig()
        await rig.model.loadAsync()
        rig.model.draft = "Hi Ana, my own words"

        await rig.model.openAsync()

        #expect(rig.model.outcome == .opened(.whatsapp))
        #expect(rig.sender.opened.first?.absoluteString.hasPrefix("https://wa.me/5511981234410?text=Hi%20Ana") == true)
        #expect(rig.messages.recentlyOpened[rig.world.ana.id] == TestClock.now)
        let logs = try await rig.world.repository.messageLogs(for: rig.world.ana.id)
        #expect(logs.map(\.template) == ["winBack"])
    }

    @Test("A client without a number gets the share sheet with the text")
    func noNumber() async throws {
        let rig = try await makeRig(client: nil)
        let beatriz = rig.world.beatriz
        let model = ClientMessageViewModel(
            request: ClientMessageRequest(clientID: beatriz.id, kind: .birthday), appointments: rig.world.appointments,
            vault: rig.world.vault, profile: rig.world.profile, setup: rig.world.bookingSetup, messages: rig.messages,
            now: { TestClock.now }
        )
        await model.loadAsync()

        #expect(!model.hasNumber)
        await model.openAsync()
        guard case .needsShareSheet(let text)? = model.outcome else {
            Issue.record("expected the share sheet")
            return
        }
        #expect(text.contains("Beatriz"))
    }

    @Test("An empty message cannot be opened")
    func emptyDraft() async throws {
        let rig = try await makeRig()
        await rig.model.loadAsync()
        rig.model.draft = "  \n "

        #expect(!rig.model.canOpen)
        await rig.model.openAsync()
        #expect(rig.model.outcome == nil)
        #expect(rig.sender.opened.isEmpty)
    }

    @Test("A client who no longer exists is reported as missing")
    func missing() async throws {
        let world = try await CalendarWorld.make()
        let model = ClientMessageViewModel(
            request: ClientMessageRequest(clientID: UUID(), kind: .winBack), appointments: world.appointments,
            vault: world.vault, profile: world.profile, setup: world.bookingSetup,
            messages: MessageService(vault: world.vault, sender: FakeMessageSender())
        )

        await model.loadAsync()

        #expect(model.isMissing && model.client == nil && !model.isLoading)
    }

    @Test("A vault that cannot be read is an error with a message")
    func unreadable() async throws {
        let world = try await CalendarWorld.make()
        let vault = VaultService(repository: nil)
        let model = ClientMessageViewModel(
            request: ClientMessageRequest(clientID: world.ana.id, kind: .winBack),
            appointments: AppointmentService(vault: vault), vault: vault, profile: world.profile,
            setup: world.bookingSetup, messages: MessageService(vault: vault, sender: FakeMessageSender())
        )

        await model.loadAsync()

        #expect(model.errorMessage != nil && !model.isLoading)
    }
}
