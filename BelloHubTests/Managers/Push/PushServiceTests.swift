//
//  PushServiceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// Push for the signed-in professional (API.md section 7): the FCM token reaches the server through the outbound
/// queue (once per token, also after being offline), a silent mailbox push syncs the sealed mailbox, a booking push
/// syncs the bookings, and sign-out unregisters the phone. Serialized: the pushes travel through the default
/// `NotificationCenter`, which every `PushService` of the process listens to.
@MainActor
@Suite("PushService", .serialized)
struct PushServiceTests {
    private struct Rig {
        let inbox: InboxRig
        let provider: FakePushTokenProvider
        let mailbox: MailboxService
        let push: PushService

        var repository: FakeInboxRepository { inbox.repository }

        func start() async {
            await inbox.start()
            push.startListening(userId: InboxRig.userID)
        }

        func cleanUp() {
            push.stopListening()
            mailbox.stopListening()
            inbox.cleanUp()
        }
    }

    private func makeRig() -> Rig {
        let inbox = InboxRig(repository: FakeInboxRepository())
        let provider = FakePushTokenProvider()
        let mailbox = MailboxService(
            repository: inbox.repository, keys: FakeInboxKeys(), vault: inbox.vault, queue: inbox.queue,
            bookings: inbox.sync, notifier: FakeImmediateNotifier(), defaults: inbox.defaults, now: { TestClock.now }
        )
        let push = PushService(
            provider: provider, queue: inbox.queue, bookings: inbox.sync, mailbox: mailbox, defaults: inbox.defaults,
            locale: { "pt-BR" }
        )
        return Rig(inbox: inbox, provider: provider, mailbox: mailbox, push: push)
    }

    // MARK: - Token registration

    @Test("Starting asks the system for push and registers the FCM token with her language")
    func registersToken() async {
        let rig = makeRig()
        defer { rig.cleanUp() }
        await rig.start()
        #expect(rig.provider.registerCount == 1)

        rig.provider.send("fcm-token-1")

        let repository = rig.repository
        #expect(await Wait.until { await repository.writes == ["registerDevice:fcm-token-1"] })
        #expect(rig.push.registeredToken == "fcm-token-1")
        #expect(rig.inbox.queue.pending.isEmpty)
    }

    @Test("The same token again is not registered twice; a refreshed token is")
    func registersOncePerToken() async {
        let rig = makeRig()
        defer { rig.cleanUp() }
        await rig.start()
        let repository = rig.repository

        rig.provider.send("fcm-token-1")
        #expect(await Wait.until { await repository.writes.count == 1 })
        rig.provider.send("fcm-token-1")
        rig.provider.send("fcm-token-2")

        #expect(await Wait.until { await repository.writes.count == 2 })
        #expect(await repository.writes == ["registerDevice:fcm-token-1", "registerDevice:fcm-token-2"])
        #expect(rig.push.registeredToken == "fcm-token-2")
    }

    @Test("A token learned offline waits in the queue and reaches the server when it answers again")
    func registrationReplaysAfterOffline() async {
        let rig = makeRig()
        defer { rig.cleanUp() }
        await rig.repository.setWriteFailure(.unreachable)
        await rig.start()
        let queue = rig.inbox.queue

        rig.provider.send("fcm-offline")

        #expect(await Wait.untilMain { queue.waitingOn == .unreachable && !queue.isFlushing })
        #expect(queue.pending.map(\.kind) == [.registerDevice(fcmToken: "fcm-offline", locale: "pt-BR")])

        await rig.repository.setWriteFailure(nil)
        await queue.flushAsync()

        #expect(queue.pending.isEmpty)
        #expect(await rig.repository.writes == ["registerDevice:fcm-offline"])
    }

    @Test("The registered token is remembered per user, so a relaunch does not register it again")
    func tokenRememberedAcrossLaunches() async {
        let rig = makeRig()
        defer { rig.cleanUp() }
        await rig.start()
        rig.provider.send("fcm-token-1")
        let repository = rig.repository
        #expect(await Wait.until { await repository.writes.count == 1 })

        rig.push.stopListening()
        #expect(rig.push.registeredToken == nil)
        let relaunched = PushService(
            provider: rig.provider, queue: rig.inbox.queue, bookings: rig.inbox.sync, mailbox: rig.mailbox,
            defaults: rig.inbox.defaults, locale: { "pt-BR" }
        )
        relaunched.startListening(userId: InboxRig.userID)
        defer { relaunched.stopListening() }

        #expect(relaunched.registeredToken == "fcm-token-1")
        rig.provider.send("fcm-token-1")
        rig.provider.send("fcm-token-3")
        #expect(await Wait.until { await repository.writes.count == 2 })
        #expect(await repository.writes.last == "registerDevice:fcm-token-3")
    }

    @Test("Sign-out unregisters the phone and forgets the token")
    func signOutUnregisters() async {
        let rig = makeRig()
        defer { rig.cleanUp() }
        await rig.start()
        rig.provider.send("fcm-token-1")
        let repository = rig.repository
        #expect(await Wait.until { await repository.writes.count == 1 })

        rig.push.clearForSignOut(userID: InboxRig.userID)

        #expect(await Wait.until { await repository.writes.last == "unregisterDevice:fcm-token-1" })
        #expect(rig.inbox.defaults.string(forKey: DefaultsKey.pushRegisteredToken + "." + InboxRig.userID) == nil)
        #expect(rig.push.registeredToken == nil)
    }

    // MARK: - Incoming pushes

    @Test("A silent mailbox push syncs the sealed mailbox")
    func mailboxPushSyncsMailbox() async {
        let rig = makeRig()
        defer { rig.cleanUp() }
        await rig.start()
        rig.mailbox.startListening(userId: InboxRig.userID)
        let repository = rig.repository
        #expect(await Wait.until { await repository.reads.filter { $0 == "mailboxItems" }.count == 1 })
        await Wait.untilMain { !rig.mailbox.isSyncing }

        // Posted until it lands: the listener subscribes from its own task, so the very first post may come before it.
        let synced = await Wait.until {
            PushEvent(kind: .mailbox, id: "item-1").post()
            return await repository.reads.filter { $0 == "mailboxItems" }.count >= 2
        }

        #expect(synced)
        #expect(rig.push.lastEvent == PushEvent(kind: .mailbox, id: "item-1"))
    }

    @Test("A booking push syncs the bookings, not the mailbox", arguments: [
        PushEvent.Kind.booking, .bookingLate, .bookingConfirmed, .rescheduleRequest, .waitlist
    ])
    func bookingPushSyncsBookings(kind: PushEvent.Kind) async {
        let rig = makeRig()
        defer { rig.cleanUp() }
        await rig.start()
        let repository = rig.repository
        let before = await repository.reads.filter { $0 == "bookings" }.count

        rig.push.handle(PushEvent(kind: kind, id: "bk-1", wasOpened: true))

        #expect(await Wait.until { await repository.reads.filter { $0 == "bookings" }.count == before + 1 })
        #expect(!(await repository.reads.contains("mailboxItems")))
        #expect(rig.push.lastEvent?.wasOpened == true)
    }

    @Test("After stopListening a push changes nothing")
    func stoppedIgnoresPushes() async {
        let rig = makeRig()
        defer { rig.cleanUp() }
        await rig.start()
        rig.push.stopListening()

        PushEvent(kind: .mailbox, id: "item-1").post()
        // Proving something does NOT happen is the one place a fixed wait is allowed (CLAUDE.md section 6).
        try? await Task.sleep(for: .milliseconds(200))

        #expect(rig.push.lastEvent == nil)
    }

    // MARK: - Payload

    @Test("The FCM payload carries only a kind and an id; anything else is not ours")
    func payloadParsing() {
        let userInfo: [AnyHashable: Any] = ["kind": "mailbox", "id": "item-1", "aps": ["content-available": 1]]
        #expect(PushEvent(userInfo: userInfo, wasOpened: false) == PushEvent(kind: .mailbox, id: "item-1"))
        #expect(PushEvent(userInfo: ["kind": "booking", "id": ""], wasOpened: true)?.id == nil)
        #expect(PushEvent(userInfo: ["kind": "marketing"], wasOpened: false) == nil)
        #expect(PushEvent(userInfo: ["id": "x"], wasOpened: false) == nil)
    }
}
