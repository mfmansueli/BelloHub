//
//  MailboxServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Her sealed mailbox (docs/06-PRIVACY-SECURITY.md section 3.5): an envelope sealed the way the page seals it is
/// opened on the phone and imported into the right client exactly once; acknowledgements go through the outbound queue
/// and survive being offline or a relaunch; check-ins and data requests wait for her. What does not open is
/// `MailboxUndecryptableTests`.
@MainActor
@Suite("MailboxService")
struct MailboxServiceTests {
    private let itemID = MailboxRig.itemID

    // MARK: - Opening and importing

    @Test("A sealed health form is opened, imported into her client, acknowledged and announced without a name")
    func importsIntake() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        await rig.repository.setMailbox([MailboxRig.item(try rig.sealedIntake())])

        await rig.start()

        let forms = try await rig.healthForms()
        let form = try #require(forms.first)
        #expect(forms.count == 1)
        #expect(form.importedFromItemID == itemID)
        #expect(form.filledBy == .client)
        #expect(form.formVersion == 3)
        #expect(form.answers["allergies"] == .choices(["latex"]))
        #expect(form.answers["medication"] == HealthAnswer.no)
        #expect(form.signedAt == CallableJSON.parse("2026-10-01T14:00:00.000Z"))
        #expect(rig.mailbox.imports.map(\.id) == [itemID])
        #expect(rig.mailbox.undecryptable.isEmpty)
        let repository = rig.repository
        let ack = "acknowledgeMailboxItem:\(itemID)"
        #expect(await Wait.until { await repository.writes == [ack] })
        let post = try #require(rig.notifier.posts.first)
        #expect(rig.notifier.posts.count == 1)
        #expect(!post.title.contains("Ana") && !post.body.contains("Ana"), "no name on the lock screen")
        #expect(!post.body.contains("latex"), "no answer on the lock screen")
    }

    @Test("A large envelope kept in Storage is fetched with getMailboxItem before it is opened")
    func fetchesStoredEnvelope() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        let stored = MailboxRig.item(nil, storagePath: "inbox/u1/\(itemID)")
        await rig.repository.setMailbox([stored], stored: [itemID: try rig.sealedIntake()])

        await rig.start()

        #expect(await rig.repository.reads.contains("mailboxItem:\(itemID)"))
        #expect(try await rig.healthForms().count == 1)
    }

    @Test("Seen again on the next sync (the acknowledge was lost), the form is not imported or announced twice")
    func importIsIdempotent() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        await rig.repository.setWriteFailure(.unreachable)
        await rig.repository.setMailbox([MailboxRig.item(try rig.sealedIntake())])
        await rig.start()

        await rig.mailbox.syncAsync()

        #expect(try await rig.healthForms().count == 1)
        #expect(rig.mailbox.imports.count == 1)
        #expect(rig.notifier.posts.count == 1)
    }

    @Test("No client for it yet: unmatched, and imported on a later sync once her visit is on the phone")
    func unmatchedThenImported() async throws {
        let rig = try await MailboxRig.make(withVisit: false)
        defer { rig.cleanUp() }
        await rig.repository.setMailbox([MailboxRig.item(try rig.sealedIntake())])
        await rig.start()
        #expect(rig.mailbox.undecryptable.map(\.reason) == [.unmatched])

        try await rig.addVisit()
        await rig.mailbox.syncAsync()

        #expect(rig.mailbox.undecryptable.isEmpty)
        #expect(try await rig.healthForms().count == 1)
    }

    @Test("While the keys are locked nothing is marked as failed; the next sync after unlocking imports it")
    func lockedKeysRetryLater() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        rig.keys.isLocked = true
        await rig.repository.setMailbox([MailboxRig.item(try rig.sealedIntake())])
        await rig.start()
        #expect(rig.mailbox.undecryptable.isEmpty)
        #expect(rig.mailbox.imports.isEmpty)

        rig.keys.isLocked = false
        await rig.mailbox.syncAsync()

        #expect(rig.mailbox.imports.count == 1)
    }

    // MARK: - Offline queue

    @Test("Offline, the acknowledge waits in the queue and is replayed when the server answers again")
    func acknowledgeReplaysAfterOffline() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        await rig.repository.setWriteFailure(.unreachable)
        await rig.repository.setMailbox([MailboxRig.item(try rig.sealedIntake())])
        await rig.start()
        let queue = rig.queue
        #expect(await Wait.untilMain { queue.waitingOn == .unreachable && !queue.isFlushing })
        #expect(queue.pending.contains { $0.kind == .acknowledgeMailboxItem(itemId: itemID) })
        #expect(try await rig.healthForms().count == 1, "imported while offline")

        await rig.repository.setWriteFailure(nil)
        await queue.flushAsync()

        #expect(queue.pending.isEmpty)
        #expect(queue.waitingOn == nil)
        #expect(await rig.repository.writes.contains("acknowledgeMailboxItem:\(itemID)"))
        #expect(await rig.repository.mailbox.isEmpty, "the item left the server")
    }

    @Test("A queued acknowledge survives a relaunch: a new queue over the same storage sends it")
    func acknowledgeSurvivesRelaunch() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        await rig.repository.setWriteFailure(.unreachable)
        await rig.repository.setMailbox([MailboxRig.item(try rig.sealedIntake())])
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
        let ack = "acknowledgeMailboxItem:\(itemID)"
        #expect(await Wait.until { await repository.writes.contains(ack) })
        #expect(await Wait.untilMain { relaunched.pending.isEmpty })
    }

    @Test("Offline, the list cannot be read: a message, nothing recorded")
    func offlineList() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        await rig.repository.setReadFailure(.unreachable)

        await rig.start()

        #expect(rig.mailbox.errorMessage != nil)
        #expect(rig.mailbox.undecryptable.isEmpty)
    }

    // MARK: - Messages

    @Test("A check-in waits in the inbox, in memory, and is acknowledged only when she marks it handled")
    func checkinWaitsForHer() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        let payload: [String: Any] = [
            "schema": 1, "bookingId": MailboxRig.bookingID, "feeling": "irritated", "note": "A bit red",
            "submittedAt": "2026-10-01T13:00:00.000Z"
        ]
        let envelope = try rig.keys.seal(payload, kind: .checkin, itemId: "ck-1")
        await rig.repository.setMailbox([MailboxRig.item(envelope, kind: .checkin, id: "ck-1")])

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
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        let payload: [String: Any] = ["request": "copy", "name": "Ana Costa", "phone": "+5511981234410"]
        let envelope = try rig.keys.seal(payload, kind: .datarequest, itemId: "dr-1")
        await rig.repository.setMailbox([MailboxRig.item(envelope, kind: .datarequest, id: "dr-1")])
        await rig.start()
        #expect(rig.mailbox.messages.count == 1)

        rig.mailbox.stopListening()

        #expect(rig.mailbox.messages.isEmpty)
        #expect(rig.mailbox.imports.isEmpty && rig.mailbox.undecryptable.isEmpty)
    }
}
