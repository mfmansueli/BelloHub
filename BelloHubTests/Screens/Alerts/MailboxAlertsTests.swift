//
//  MailboxAlertsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The "From your clients" section of Alerts: every opened message and every item that did not open becomes a card,
/// oldest first, and each card's action acknowledges it on the server.
@MainActor
@Suite("MailboxAlerts")
struct MailboxAlertsTests {
    private func checkin(
        _ id: String, minutesAgo: Double, feeling: String = "irritated", note: String? = " Red "
    ) -> MailboxMessage {
        MailboxMessage(
            id: id, bookingId: "bk-1", content: .checkin(feeling: feeling, note: note, photo: nil),
            receivedAt: TestClock.now.addingTimeInterval(-minutesAgo * 60), submittedAt: nil
        )
    }

    private func makeAlerts(vault: VaultService, mailbox: MailboxService) -> AlertsViewModel {
        let permissions = PermissionService(provider: FakePermissionStatusProvider(status: .granted))
        let appointments = AppointmentService(vault: vault)
        let notifications = NotificationService(
            appointments: appointments, vault: vault, permissions: permissions, profile: ProfileService(vault: vault),
            prefs: FixedNotificationPrefsStore(), scheduler: FakeNotificationScheduler(), now: { TestClock.now }
        )
        return AlertsViewModel(
            settings: CalendarSettings(profile: nil, fallbackTimeZoneID: "America/Sao_Paulo"),
            digest: AgendaDigestService(
                appointments: appointments, timeBlocks: TimeBlockService(vault: vault), vault: vault
            ),
            bookingSetup: BookingSetupService(vault: vault), permissions: permissions, notifications: notifications,
            prefs: FixedNotificationPrefsStore(), mailbox: mailbox
        )
    }

    @Test("Messages first, oldest first, then what did not open; notes are trimmed and blanks dropped")
    func order() {
        let request = MailboxMessage(
            id: "dr-1", bookingId: "bk-2",
            content: .dataRequest(request: "delete", name: "Ana Costa", phone: "+5511981234410", note: "  "),
            receivedAt: TestClock.now.addingTimeInterval(-3_600), submittedAt: nil
        )
        let alerts = MailboxAlerts.make(
            messages: [checkin("ck-new", minutesAgo: 5), request, checkin("ck-old", minutesAgo: 90, feeling: "weird")],
            undecryptable: [
                UndecryptableItem(id: "u-2", kind: .intake, reason: .unmatched, at: TestClock.now),
                UndecryptableItem(id: "u-1", kind: .intake, reason: .openFailed, at: TestClock.days(-1))
            ],
            imports: []
        )

        #expect(alerts.items.map(\.id) == ["ck-old", "dr-1", "ck-new", "u-1", "u-2"])
        #expect(alerts.items[0] == .checkin(id: "ck-old", feeling: .okay, note: "Red", hasPhoto: false))
        #expect(alerts.items[1] == .dataRequest(
            id: "dr-1", isDeletion: true, name: "Ana Costa", phone: "+5511981234410", note: nil
        ))
        #expect(alerts.items[3] == .unopened(id: "u-1"))
        #expect(alerts.items[4] == .unmatched(id: "u-2"))
        #expect(alerts.items.filter(\.isMessage).count == 3)
    }

    @Test("Imported forms alone make the section appear; nothing at all keeps it away")
    func emptiness() {
        let imported = HealthFormImport(id: "it-1", clientID: UUID(), formID: UUID(), at: TestClock.now)
        #expect(!MailboxAlerts.make(messages: [], undecryptable: [], imports: [imported]).isEmpty)
        #expect(MailboxAlerts.make(messages: [], undecryptable: [], imports: []).isEmpty)
    }

    @Test("Handling a card acknowledges it on the server: messages are handled, unopened items dismissed")
    func resolveAcknowledges() async throws {
        let rig = try await MailboxRig.make()
        defer { rig.cleanUp() }
        let payload: [String: Any] = ["schema": 1, "bookingId": MailboxRig.bookingID, "request": "copy",
                                      "name": "Ana Costa", "phone": "+5511981234410"]
        let request = try rig.keys.seal(payload, kind: .datarequest, itemId: "dr-1")
        let stranger = try FakeInboxKeys().seal(MailboxRig.intake(), kind: .intake, itemId: "u-1")
        await rig.repository.setMailbox([
            MailboxRig.item(request, kind: .datarequest, id: "dr-1"), MailboxRig.item(stranger, id: "u-1")
        ])
        await rig.start()
        let alerts = MailboxAlerts.make(
            messages: rig.mailbox.messages, undecryptable: rig.mailbox.undecryptable, imports: rig.mailbox.imports
        )
        #expect(alerts.items.map(\.id) == ["dr-1", "u-1"])
        let viewModel = makeAlerts(vault: rig.inbox.vault, mailbox: rig.mailbox)
        #expect(viewModel.mailboxAlerts == alerts)

        for item in alerts.items { viewModel.resolve(item) }

        #expect(viewModel.mailboxAlerts.isEmpty)
        let repository = rig.repository
        #expect(await Wait.until {
            let writes = await repository.writes
            return writes.contains("acknowledgeMailboxItem:dr-1") && writes.contains("acknowledgeMailboxItem:u-1")
        })
    }
}
