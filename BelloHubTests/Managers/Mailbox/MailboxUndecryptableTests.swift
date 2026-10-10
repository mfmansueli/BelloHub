//
//  MailboxUndecryptableTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// What does not open or does not read (docs/06-PRIVACY-SECURITY.md section 3.5, step 5): remembered by id, reason and
/// time only, never imported, left on the server until its TTL unless she dismisses it, and kept across launches until
/// she signs out.
@MainActor
@Suite("MailboxService undecryptable")
struct MailboxUndecryptableTests {
    private let itemID = MailboxRig.itemID

    @Test("An envelope for a key she does not hold is unknownKey, kept on the server and across launches")
    func unknownKey() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        let envelope = try FakeInboxKeys().seal(MailboxRig.intake(), kind: .intake, itemId: itemID)
        await rig.repository.setMailbox([MailboxRig.item(envelope)])

        await rig.start()

        #expect(rig.mailbox.undecryptable.map(\.reason) == [.unknownKey])
        #expect(rig.mailbox.undecryptable.first?.at == TestClock.now)
        #expect(await rig.repository.writes.isEmpty, "left on the server until its TTL")

        rig.mailbox.stopListening()
        rig.mailbox.startListening(userId: InboxRig.userID)
        #expect(rig.mailbox.undecryptable.map(\.id) == [itemID], "restored from storage (ids and times only)")
        await Wait.untilMain(timeout: .seconds(10)) { !rig.mailbox.isSyncing }

        rig.mailbox.dismissUndecryptable(id: itemID)
        #expect(rig.mailbox.undecryptable.isEmpty)
        let repository = rig.repository
        let ack = "acknowledgeMailboxItem:\(itemID)"
        #expect(await Wait.until { await repository.writes.contains(ack) })
    }

    @Test("A tampered ciphertext does not open")
    func tampered() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        let sealed = try rig.sealedIntake()
        var bytes = try #require(Data(base64URL: sealed.ct))
        bytes[0] ^= 0xFF
        let tampered = SealedEnvelope(
            keyId: sealed.keyId, kind: sealed.kind, itemId: sealed.itemId, enc: sealed.enc,
            ct: bytes.base64URLEncodedString()
        )
        await rig.repository.setMailbox([MailboxRig.item(tampered)])

        await rig.start()

        #expect(rig.mailbox.undecryptable.map(\.reason) == [.openFailed])
        #expect(try await rig.healthForms().isEmpty)
    }

    @Test("An envelope moved to another item id is refused before any key is used")
    func misaddressed() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        let envelope = try rig.keys.seal(MailboxRig.intake(), kind: .intake, itemId: "another-item")
        await rig.repository.setMailbox([MailboxRig.item(envelope)])

        await rig.start()

        #expect(rig.mailbox.undecryptable.map(\.reason) == [.openFailed])
        #expect(rig.keys.lookups.isEmpty)
    }

    @Test("Another envelope version is unsupported and never touches a key")
    func unsupportedVersion() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        let sealed = try rig.sealedIntake()
        let future = SealedEnvelope(
            version: 2, keyId: sealed.keyId, kind: sealed.kind, itemId: sealed.itemId, enc: sealed.enc, ct: sealed.ct
        )
        await rig.repository.setMailbox([MailboxRig.item(future)])

        await rig.start()

        #expect(rig.mailbox.undecryptable.map(\.reason) == [.unsupported])
        #expect(rig.keys.lookups.isEmpty)
    }

    @Test("It opens but is not a health form: badPayload, nothing imported")
    func badPayload() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        let envelope = try rig.keys.seal(["schema": 9, "hello": "world"], kind: .intake, itemId: itemID)
        await rig.repository.setMailbox([MailboxRig.item(envelope)])

        await rig.start()

        #expect(rig.mailbox.undecryptable.map(\.reason) == [.badPayload])
        #expect(try await rig.healthForms().isEmpty)
    }

    @Test("Sign-out removes what was stored for her")
    func signOutClears() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        let envelope = try FakeInboxKeys().seal(MailboxRig.intake(), kind: .intake, itemId: itemID)
        await rig.repository.setMailbox([MailboxRig.item(envelope)])
        await rig.start()
        #expect(rig.mailbox.undecryptable.count == 1)

        rig.mailbox.clearForSignOut(userID: InboxRig.userID)
        await rig.repository.setMailbox([])
        rig.mailbox.startListening(userId: InboxRig.userID)

        #expect(rig.mailbox.undecryptable.isEmpty)
    }
}
