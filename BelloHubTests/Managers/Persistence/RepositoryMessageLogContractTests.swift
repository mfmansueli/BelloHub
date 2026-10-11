//
//  RepositoryMessageLogContractTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("Repository contract: message log", .serialized)
struct RepositoryMessageLogContractTests {
    private let fixture = ContractFixture()

    private func log(_ client: UUID, _ when: String, template: String = "followUp") -> MessageLog {
        MessageLog(id: UUID(), clientID: client, channel: .whatsapp, template: template, openedAt: TestClock.date(when))
    }

    @Test("Every client's chats opened since a moment come back, newest first", arguments: RepositoryFlavor.allCases)
    func since(flavor: RepositoryFlavor) async throws {
        let repository = try flavor.make(clock: fixture.clock)
        let ana = UUID()
        let bia = UUID()
        let old = log(ana, "2026-09-01 10:00")
        let recent = log(ana, "2026-10-07 10:00", template: "winBack")
        let newest = log(bia, "2026-10-08 09:00", template: "reminder")
        for item in [old, recent, newest] { try await repository.save(item) }

        let found = try await repository.messageLogs(since: TestClock.date("2026-10-01 00:00"))

        #expect(found.map(\.id) == [newest.id, recent.id])
        #expect(found.map(\.template) == ["reminder", "winBack"])
    }
}
