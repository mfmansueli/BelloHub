//
//  MailboxRig.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// A `MailboxService` over the `InboxRig` (fake inbox server, in-memory vault, outbound queue with no automatic
/// retry), a fresh inbox key pair and a notifier that records. The vault holds Ana Costa and, unless asked otherwise, a
/// visit that came from booking `bk-1`, so a form for that booking finds her.
@MainActor
struct MailboxRig {
    static let bookingID = "bk-1"
    static let itemID = "7f0f4c6e-1c2b-4d6a-9a1e-000000000001"

    let inbox: InboxRig
    let keys: FakeInboxKeys
    let notifier: FakeImmediateNotifier
    let mailbox: MailboxService
    let clientID: UUID

    var repository: FakeInboxRepository { inbox.repository }
    var queue: OutboundQueue { inbox.queue }

    static func make(withVisit: Bool = true) async throws -> MailboxRig {
        let inbox = InboxRig(repository: FakeInboxRepository())
        let repository = try #require(inbox.vault.repository)
        let client = makeClient(name: "Ana Costa")
        _ = try await repository.save(client)
        let rig = MailboxRig(inbox: inbox, clientID: client.id)
        if withVisit { try await rig.addVisit() }
        return rig
    }

    private init(inbox: InboxRig, clientID: UUID) {
        self.inbox = inbox
        self.clientID = clientID
        keys = FakeInboxKeys()
        notifier = FakeImmediateNotifier()
        mailbox = MailboxService(
            repository: inbox.repository, keys: keys, vault: inbox.vault, queue: inbox.queue, bookings: inbox.sync,
            notifier: notifier, defaults: inbox.defaults, now: { TestClock.now }
        )
    }

    func vaultRepository() throws -> any ClientRecordRepository {
        try #require(inbox.vault.repository)
    }

    /// Her visit from booking `bk-1` arrives on the phone.
    func addVisit() async throws {
        var visit = makeAppointment(clientID: clientID, daysFromNow: 2, status: .confirmed)
        visit.bookingID = Self.bookingID
        try await vaultRepository().save(visit)
    }

    func healthForms() async throws -> [HealthForm] {
        try await vaultRepository().healthForms(for: clientID)
    }

    /// Starts the session and waits until the first mailbox sync is over.
    func start() async {
        await inbox.start()
        mailbox.startListening(userId: InboxRig.userID)
        await Wait.untilMain(timeout: .seconds(10)) { !mailbox.isSyncing }
        let repository = repository
        await Wait.until(timeout: .seconds(10)) { await repository.reads.contains("mailboxItems") }
        await Wait.untilMain(timeout: .seconds(10)) { !mailbox.isSyncing }
    }

    func cleanUp() {
        mailbox.stopListening()
        inbox.cleanUp()
    }

    // MARK: - Payloads and items

    /// A schema-2 health form for `bk-1`, as the page writes it.
    static func intake(bookingID: String = bookingID) -> [String: Any] {
        [
            "schema": 2, "bookingId": bookingID, "localeId": "pt-BR", "formVersion": "3",
            "answers": ["allergies": ["latex"], "medication": false, "anythingElse": "Sensitive skin"],
            "isForMinor": false, "submittedAt": "2026-10-01T14:00:00.000Z", "_pad": "    "
        ]
    }

    /// An intake sealed to her key, as item `itemID`.
    func sealedIntake() throws -> SealedEnvelope {
        try keys.seal(Self.intake(), kind: .intake, itemId: Self.itemID)
    }

    /// The server's listing of one item for `bk-1`, with its envelope or (nil) kept in Storage.
    static func item(
        _ envelope: SealedEnvelope?, kind: MailboxKind = .intake, id: String = itemID, storagePath: String? = nil
    ) -> MailboxItem {
        MailboxItem(
            id: id, kind: kind, bookingId: bookingID, keyId: envelope?.keyId, sizeBytes: 900,
            createdAt: TestClock.now.addingTimeInterval(-600), envelope: envelope, storagePath: storagePath
        )
    }
}
