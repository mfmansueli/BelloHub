//
//  MailboxServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Her sealed mailbox (docs/06-PRIVACY-SECURITY.md section 3.5): an envelope sealed the way the page seals it is
/// opened on the phone and imported into the right client exactly once; acknowledgements go through the outbound queue
/// and survive being offline; anything that does not open is remembered by id and reason only and left on the server.
@MainActor
@Suite("MailboxService")
struct MailboxServiceTests {
    private struct Rig {
        let inbox: InboxRig
        let keys: FakeInboxKeys
        let notifier: FakeImmediateNotifier
        let mailbox: MailboxService
        let clientID: UUID

        var repository: FakeInboxRepository { inbox.repository }
        var queue: OutboundQueue { inbox.queue }

        func vaultRepository() throws -> any ClientRecordRepository {
            try #require(inbox.vault.repository)
        }

        /// Starts the session and waits until the first mailbox sync is over.
        func start() async {
            await inbox.start()
            mailbox.startListening(userId: InboxRig.userID)
            await waitForSync()
        }

        func waitForSync() async {
            await Wait.untilMain(timeout: .seconds(10)) { !mailbox.isSyncing }
            let repository = repository
            await Wait.until(timeout: .seconds(10)) { await repository.reads.contains("mailboxItems") }
            await Wait.untilMain(timeout: .seconds(10)) { !mailbox.isSyncing }
        }

        func cleanUp() {
            mailbox.stopListening()
            inbox.cleanUp()
        }
    }

    private static let bookingID = "bk-1"
    private static let itemID = "7f0f4c6e-1c2b-4d6a-9a1e-000000000001"

    /// A client with a visit that came from booking `bk-1`, so a form for that booking finds her.
    private func makeRig(withVisit: Bool = true) async throws -> Rig {
        let inbox = InboxRig(repository: FakeInboxRepository())
        let repository = try #require(inbox.vault.repository)
        let client = makeClient(name: "Ana Costa")
        _ = try await repository.save(client)
        if withVisit {
            var visit = makeAppointment(clientID: client.id, daysFromNow: 2, status: .confirmed)
            visit.bookingID = Self.bookingID
            try await repository.save(visit)
        }
        let keys = FakeInboxKeys()
        let notifier = FakeImmediateNotifier()
        let mailbox = MailboxService(
            repository: inbox.repository, keys: keys, vault: inbox.vault, queue: inbox.queue, bookings: inbox.sync,
            notifier: notifier, defaults: inbox.defaults, now: { TestClock.now }
        )
        return Rig(inbox: inbox, keys: keys, notifier: notifier, mailbox: mailbox, clientID: client.id)
    }

    private static let intake: [String: Any] = [
        "schema": 2, "bookingId": bookingID, "localeId": "pt-BR", "formVersion": "3",
        "answers": ["allergies": ["latex"], "medication": false, "anythingElse": "Sensitive skin"],
        "isForMinor": false, "submittedAt": "2026-10-01T14:00:00.000Z", "_pad": "    "
    ]

    private func item(
        _ envelope: SealedEnvelope?, kind: MailboxKind = .intake, id: String = itemID, storagePath: String? = nil
    ) -> MailboxItem {
        MailboxItem(
            id: id, kind: kind, bookingId: Self.bookingID, keyId: envelope?.keyId, sizeBytes: 900,
            createdAt: TestClock.now.addingTimeInterval(-600), envelope: envelope, storagePath: storagePath
        )
    }

    // MARK: - Opening and importing

    @Test("A sealed health form is opened, imported into her client, acknowledged and announced without a name")
    func importsIntake() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        let envelope = try rig.keys.seal(Self.intake, kind: .intake, itemId: Self.itemID)
        await rig.repository.setMailbox([item(envelope)])

        await rig.start()

        let forms = try await rig.vaultRepository().healthForms(for: rig.clientID)
        let form = try #require(forms.first)
        #expect(forms.count == 1)
        #expect(form.importedFromItemID == Self.itemID)
        #expect(form.filledBy == .client)
        #expect(form.formVersion == 3)
        #expect(form.answers["allergies"] == .choices(["latex"]))
        #expect(form.answers["medication"] == .no)
        #expect(form.signedAt == CallableJSON.parse("2026-10-01T14:00:00.000Z"))
        #expect(rig.mailbox.imports.map(\.id) == [Self.itemID])
        #expect(rig.mailbox.undecryptable.isEmpty)
        let repository = rig.repository
        #expect(await Wait.until { await repository.writes == ["acknowledgeMailboxItem:\(Self.itemID)"] })
        let post = try #require(rig.notifier.posts.first)
        #expect(rig.notifier.posts.count == 1)
        #expect(!post.title.contains("Ana") && !post.body.contains("Ana"), "no name on the lock screen")
        #expect(!post.body.contains("latex"), "no answer on the lock screen")
    }

    @Test("A large envelope kept in Storage is fetched with getMailboxItem before it is opened")
    func fetchesStoredEnvelope() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        let envelope = try rig.keys.seal(Self.intake, kind: .intake, itemId: Self.itemID)
        await rig.repository.setMailbox(
            [item(nil, storagePath: "inbox/u1/\(Self.itemID)")], stored: [Self.itemID: envelope]
        )

        await rig.start()

        #expect(await rig.repository.reads.contains("mailboxItem:\(Self.itemID)"))
        #expect(try await rig.vaultRepository().healthForms(for: rig.clientID).count == 1)
    }

    @Test("Seen again on the next sync (the acknowledge was lost), the form is not imported or announced twice")
    func importIsIdempotent() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        await rig.repository.setWriteFailure(.unreachable)
        let envelope = try rig.keys.seal(Self.intake, kind: .intake, itemId: Self.itemID)
        await rig.repository.setMailbox([item(envelope)])
        await rig.start()

        await rig.mailbox.syncAsync()

        #expect(try await rig.vaultRepository().healthForms(for: rig.clientID).count == 1)
        #expect(rig.mailbox.imports.count == 1)
        #expect(rig.notifier.posts.count == 1)
    }

    // MARK: - Offline queue

    @Test("Offline, the acknowledge waits in the queue and is replayed when the server answers again")
    func acknowledgeReplaysAfterOffline() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        await rig.repository.setWriteFailure(.unreachable)
        let envelope = try rig.keys.seal(Self.intake, kind: .intake, itemId: Self.itemID)
        await rig.repository.setMailbox([item(envelope)])
        await rig.start()
        let queue = rig.queue
        #expect(await Wait.untilMain { queue.waitingOn == .unreachable && !queue.isFlushing })
        #expect(queue.pending.contains { $0.kind == .acknowledgeMailboxItem(itemId: Self.itemID) })
        #expect(try await rig.vaultRepository().healthForms(for: rig.clientID).count == 1, "imported while offline")

        await rig.repository.setWriteFailure(nil)
        await queue.flushAsync()

        #expect(queue.pending.isEmpty)
        #expect(queue.waitingOn == nil)
        #expect(await rig.repository.writes.contains("acknowledgeMailboxItem:\(Self.itemID)"))
        #expect(await rig.repository.mailbox.isEmpty, "the item left the server")
    }

    @Test("A queued acknowledge survives a relaunch: a new queue over the same storage sends it")
    func acknowledgeSurvivesRelaunch() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        await rig.repository.setWriteFailure(.unreachable)
        let envelope = try rig.keys.seal(Self.intake, kind: .intake, itemId: Self.itemID)
        await rig.repository.setMailbox([item(envelope)])
        await rig.start()
        let queue = rig.queue
        #expect(await Wait.untilMain { !queue.pending.isEmpty && !queue.isFlushing })
        rig.inbox.sync.stopListening()

        await rig.repository.setWriteFailure(nil)
        let relaunched = OutboundQueue(
            repository: rig.repository, defaults: rig.inbox.defaults, now: { TestClock.now },
            retryDelays: [.seconds(600)]
        )
        relaunched.start(userID: InboxRig.userID)
        defer { relaunched.stop() }

        let repository = rig.repository
        #expect(await Wait.until { await repository.writes.contains("acknowledgeMailboxItem:\(Self.itemID)") })
        #expect(await Wait.untilMain { relaunched.pending.isEmpty })
    }

    // MARK: - Messages

    @Test("A check-in waits in the inbox, in memory, and is acknowledged only when she marks it handled")
    func checkinWaitsForHer() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        let payload: [String: Any] = [
            "schema": 1, "bookingId": Self.bookingID, "feeling": "irritated", "note": "A bit red",
            "submittedAt": "2026-10-01T13:00:00.000Z"
        ]
        let envelope = try rig.keys.seal(payload, kind: .checkin, itemId: "ck-1")
        await rig.repository.setMailbox([item(envelope, kind: .checkin, id: "ck-1")])

        await rig.start()

        let message = try #require(rig.mailbox.messages.first)
        #expect(message.content == .checkin(feeling: "irritated", note: "A bit red", photo: nil))
        #expect(await rig.repository.writes.isEmpty, "not acknowledged before she handled it")
        #expect(rig.notifier.posts.isEmpty)

        rig.mailbox.markHandled(messageID: "ck-1")

        #expect(rig.mailbox.messages.isEmpty)
        let repository = rig.repository
        #expect(await Wait.until { await repository.writes == ["acknowledgeMailboxItem:ck-1"] })
    }

    @Test("Locking forgets what was opened")
    func stopForgetsMessages() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        let payload: [String: Any] = ["request": "copy", "name": "Ana Costa", "phone": "+5511981234410"]
        let envelope = try rig.keys.seal(payload, kind: .datarequest, itemId: "dr-1")
        await rig.repository.setMailbox([item(envelope, kind: .datarequest, id: "dr-1")])
        await rig.start()
        #expect(rig.mailbox.messages.count == 1)

        rig.mailbox.stopListening()

        #expect(rig.mailbox.messages.isEmpty)
        #expect(rig.mailbox.imports.isEmpty && rig.mailbox.undecryptable.isEmpty)
    }

    // MARK: - What does not open

    @Test("An envelope for a key she does not hold is remembered as unknownKey, kept on the server and across launches")
    func unknownKey() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        let stranger = FakeInboxKeys()
        let envelope = try stranger.seal(Self.intake, kind: .intake, itemId: Self.itemID)
        await rig.repository.setMailbox([item(envelope)])

        await rig.start()

        #expect(rig.mailbox.undecryptable.map(\.reason) == [.unknownKey])
        #expect(rig.mailbox.undecryptable.first?.at == TestClock.now)
        #expect(await rig.repository.writes.isEmpty, "left on the server until its TTL")

        rig.mailbox.stopListening()
        rig.mailbox.startListening(userId: InboxRig.userID)
        #expect(rig.mailbox.undecryptable.map(\.id) == [Self.itemID], "restored from storage (ids and times only)")
        await Wait.untilMain(timeout: .seconds(10)) { !rig.mailbox.isSyncing }

        rig.mailbox.dismissUndecryptable(id: Self.itemID)
        #expect(rig.mailbox.undecryptable.isEmpty)
        let repository = rig.repository
        #expect(await Wait.until { await repository.writes == ["acknowledgeMailboxItem:\(Self.itemID)"] })
    }

    @Test("A tampered ciphertext does not open")
    func tampered() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        let sealed = try rig.keys.seal(Self.intake, kind: .intake, itemId: Self.itemID)
        var bytes = try #require(Data(base64URL: sealed.ct))
        bytes[0] ^= 0xFF
        let tampered = SealedEnvelope(
            keyId: sealed.keyId, kind: sealed.kind, itemId: sealed.itemId, enc: sealed.enc,
            ct: bytes.base64URLEncodedString()
        )
        await rig.repository.setMailbox([item(tampered)])

        await rig.start()

        #expect(rig.mailbox.undecryptable.map(\.reason) == [.openFailed])
        #expect(try await rig.vaultRepository().healthForms(for: rig.clientID).isEmpty)
    }

    @Test("An envelope moved to another item id is refused before any key is used")
    func misaddressed() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        let envelope = try rig.keys.seal(Self.intake, kind: .intake, itemId: "another-item")
        await rig.repository.setMailbox([item(envelope)])

        await rig.start()

        #expect(rig.mailbox.undecryptable.map(\.reason) == [.openFailed])
        #expect(rig.keys.lookups.isEmpty)
    }

    @Test("Another envelope version is unsupported and never touches a key")
    func unsupportedVersion() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        let sealed = try rig.keys.seal(Self.intake, kind: .intake, itemId: Self.itemID)
        let future = SealedEnvelope(
            version: 2, keyId: sealed.keyId, kind: sealed.kind, itemId: sealed.itemId, enc: sealed.enc, ct: sealed.ct
        )
        await rig.repository.setMailbox([item(future)])

        await rig.start()

        #expect(rig.mailbox.undecryptable.map(\.reason) == [.unsupported])
        #expect(rig.keys.lookups.isEmpty)
    }

    @Test("It opens but is not a health form: badPayload")
    func badPayload() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        let envelope = try rig.keys.seal(["schema": 9, "hello": "world"], kind: .intake, itemId: Self.itemID)
        await rig.repository.setMailbox([item(envelope)])

        await rig.start()

        #expect(rig.mailbox.undecryptable.map(\.reason) == [.badPayload])
    }

    @Test("No client for it yet: unmatched, and imported on a later sync once her visit is on the phone")
    func unmatchedThenImported() async throws {
        let rig = try await makeRig(withVisit: false)
        defer { rig.cleanUp() }
        let envelope = try rig.keys.seal(Self.intake, kind: .intake, itemId: Self.itemID)
        await rig.repository.setMailbox([item(envelope)])
        await rig.start()
        #expect(rig.mailbox.undecryptable.map(\.reason) == [.unmatched])

        var visit = makeAppointment(clientID: rig.clientID, daysFromNow: 2, status: .confirmed)
        visit.bookingID = Self.bookingID
        try await rig.vaultRepository().save(visit)
        await rig.mailbox.syncAsync()

        #expect(rig.mailbox.undecryptable.isEmpty)
        #expect(try await rig.vaultRepository().healthForms(for: rig.clientID).count == 1)
    }

    @Test("While the keys are locked nothing is marked as failed; the next sync after unlocking imports it")
    func lockedKeysRetryLater() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        rig.keys.isLocked = true
        let envelope = try rig.keys.seal(Self.intake, kind: .intake, itemId: Self.itemID)
        await rig.repository.setMailbox([item(envelope)])
        await rig.start()
        #expect(rig.mailbox.undecryptable.isEmpty)
        #expect(rig.mailbox.imports.isEmpty)

        rig.keys.isLocked = false
        await rig.mailbox.syncAsync()

        #expect(rig.mailbox.imports.count == 1)
    }

    @Test("Offline, the list cannot be read: a message, nothing recorded")
    func offlineList() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        await rig.repository.setReadFailure(.unreachable)

        await rig.start()

        #expect(rig.mailbox.errorMessage != nil)
        #expect(rig.mailbox.undecryptable.isEmpty)
    }

    @Test("Sign-out removes what was stored for her")
    func signOutClears() async throws {
        let rig = try await makeRig()
        defer { rig.cleanUp() }
        let stranger = FakeInboxKeys()
        let envelope = try stranger.seal(Self.intake, kind: .intake, itemId: Self.itemID)
        await rig.repository.setMailbox([item(envelope)])
        await rig.start()
        #expect(rig.mailbox.undecryptable.count == 1)

        rig.mailbox.clearForSignOut(userID: InboxRig.userID)
        await rig.repository.setMailbox([])
        rig.mailbox.startListening(userId: InboxRig.userID)

        #expect(rig.mailbox.undecryptable.isEmpty)
    }
}
