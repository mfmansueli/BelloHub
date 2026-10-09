//
//  MessageServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("MessageService")
@MainActor
struct MessageServiceTests {
    private let phone = "+5511981234410"
    private let clientID = UUID()

    private func makeService(sender: FakeMessageSender = FakeMessageSender())
        -> (MessageService, InMemoryClientRecordRepository, FakeMessageSender) {
        let repository = InMemoryClientRecordRepository(clock: { TestClock.now })
        return (MessageService(repository: repository, sender: sender), repository, sender)
    }

    @Test("WhatsApp opens with the text ready and one log entry is kept, without the text")
    func opensWhatsApp() async throws {
        let (service, repository, sender) = makeService()

        let outcome = await service.send(
            text: "Hi Ana", to: clientID, phoneE164: phone, template: "noShowNote", now: TestClock.now
        )

        #expect(outcome == .opened(.whatsapp))
        #expect(sender.opened.map(\.absoluteString) == ["https://wa.me/5511981234410?text=Hi%20Ana"])
        let logs = try await repository.messageLogs(for: clientID)
        #expect(logs.count == 1)
        #expect(logs.first?.channel == .whatsapp)
        #expect(logs.first?.template == "noShowNote")
        #expect(logs.first?.openedAt == TestClock.now)
        let stored = try String(data: JSONEncoder().encode(logs), encoding: .utf8) ?? ""
        #expect(!stored.contains("Hi Ana"))
    }

    @Test("Without WhatsApp the Messages app opens instead")
    func fallsBackToMessages() async throws {
        let sender = FakeMessageSender()
        sender.whatsAppInstalled = false
        let (service, repository, _) = makeService(sender: sender)

        let outcome = await service.send(text: "Hi", to: clientID, phoneE164: phone, template: "late")

        #expect(outcome == .opened(.sms))
        #expect(sender.opened.count == 2)
        #expect(try await repository.messageLogs(for: clientID).map(\.channel) == [.sms])
    }

    @Test("Without either app the share sheet is the answer, and it is logged as shared")
    func fallsBackToShare() async throws {
        let sender = FakeMessageSender()
        sender.whatsAppInstalled = false
        sender.messagesAvailable = false
        let (service, repository, _) = makeService(sender: sender)

        let outcome = await service.send(text: "Hi", to: clientID, phoneE164: phone, template: "late")

        #expect(outcome == .needsShareSheet(text: "Hi"))
        #expect(try await repository.messageLogs(for: clientID).map(\.channel) == [.share])
    }

    @Test("A client without a number goes straight to the share sheet and nothing is opened")
    func noNumber() async {
        let (service, _, sender) = makeService()

        let outcome = await service.send(text: "Hi", to: clientID, phoneE164: nil, template: "confirm")

        #expect(outcome == .needsShareSheet(text: "Hi"))
        #expect(sender.opened.isEmpty)
    }

    @Test("Where people text, Messages is tried before WhatsApp")
    func preferredChannel() async {
        let (service, _, sender) = makeService()

        let outcome = await service.send(
            text: "Hi", to: clientID, phoneE164: phone, template: "confirm", preferred: .messages
        )

        #expect(outcome == .opened(.sms))
        #expect(sender.opened.first?.scheme == "sms")
    }

    @Test("Without a vault the message still opens: the log is a convenience")
    func noVault() async {
        let sender = FakeMessageSender()
        let service = MessageService(vault: VaultService(repository: nil), sender: sender)

        let outcome = await service.send(text: "Hi", to: clientID, phoneE164: phone, template: "confirm")

        #expect(outcome == .opened(.whatsapp))
    }
}
