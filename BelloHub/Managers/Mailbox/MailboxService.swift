//
//  MailboxService.swift
//  BelloHub
//

import CryptoKit
import Foundation
import Observation

/// Her sealed mailbox (docs/06-PRIVACY-SECURITY.md section 3.5): the only code that holds the inbox private key while
/// an envelope is open (docs/04-ARCHITECTURE.md, boundary 3). `sync()` runs on start, on a silent push, on foreground
/// and on pull-to-refresh. For each item: fetch the envelope, find the key by `keyId`, open, read the payload, then:
/// - a health form goes into the client's record **once per item** (`importHealthForm` is idempotent by item id, so a
///   crash between the import and the acknowledge is safe), is acknowledged through the `OutboundQueue`, and raises
///   a generic local alert ("A client sent her health form", no name);
/// - a check-in or a data request is shown in the inbox until she marks it handled, and only then acknowledged;
/// - anything that does not open or does not read is remembered by id and time (`UndecryptableItem`), left on the
///   server until its TTL, and the inbox asks her to have the client send it again.
@MainActor
@Observable
final class MailboxService {
    /// Check-ins and data requests opened on the phone, waiting for her. In memory only (a check-in may carry a photo).
    private(set) var messages: [MailboxMessage] = []
    private(set) var undecryptable: [UndecryptableItem] = []
    /// Forms imported and not yet opened from the inbox.
    private(set) var imports: [HealthFormImport] = []
    private(set) var isSyncing = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let repository: any InboxRepository
    @ObservationIgnored private let keys: any InboxKeyOpening
    @ObservationIgnored private let vault: VaultService
    @ObservationIgnored private let queue: OutboundQueue
    @ObservationIgnored private let bookings: BookingSyncService
    @ObservationIgnored private let notifier: any ImmediateNotifying
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var userID: String?
    @ObservationIgnored private var syncTask: Task<Void, Never>?

    init(
        repository: any InboxRepository,
        keys: any InboxKeyOpening,
        vault: VaultService,
        queue: OutboundQueue,
        bookings: BookingSyncService,
        notifier: any ImmediateNotifying = UserNotificationPoster(),
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.keys = keys
        self.vault = vault
        self.queue = queue
        self.bookings = bookings
        self.notifier = notifier
        self.defaults = defaults
        self.now = now
    }

    // MARK: - Listening

    func startListening(userId: String) {
        guard userID != userId else { return }
        stopListening()
        userID = userId
        let stored: Stored = Self.load(defaults, key: Self.key(userId)) ?? Stored()
        undecryptable = stored.undecryptable
        imports = stored.imports
        syncNow()
    }

    /// Lock or sign-out: nothing opened stays in memory.
    func stopListening() {
        syncTask?.cancel()
        syncTask = nil
        userID = nil
        messages = []
        undecryptable = []
        imports = []
        errorMessage = nil
        isSyncing = false
    }

    func clearForSignOut(userID: String) {
        defaults.removeObject(forKey: Self.key(userID))
        stopListening()
    }

    // MARK: - Sync

    /// Fire-and-forget (a silent push, the app coming to the foreground).
    func syncNow() {
        guard syncTask == nil else { return }
        syncTask = Task { [weak self] in
            await self?.syncAsync()
            self?.syncTask = nil
        }
    }

    func syncAsync() async {
        guard let userID, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let items: [MailboxItem]
        do {
            items = try await repository.mailboxItems(uid: userID)
        } catch {
            errorMessage = BookingSyncService.text(for: error)
            return
        }
        errorMessage = nil
        for item in items where self.userID == userID {
            if let known = undecryptable.first(where: { $0.id == item.id }), known.reason != .unmatched { continue }
            if messages.contains(where: { $0.id == item.id }) { continue }
            await process(item)
        }
        queue.flush()
    }

    // MARK: - Her actions

    /// She dealt with a check-in or a data request: it leaves the inbox and the server.
    func markHandled(messageID: String) {
        messages.removeAll { $0.id == messageID }
        queue.enqueue(.acknowledgeMailboxItem(itemId: messageID))
    }

    /// She gave up on an item that does not open: it leaves the list and the server.
    func dismissUndecryptable(id: String) {
        undecryptable.removeAll { $0.id == id }
        persist()
        queue.enqueue(.acknowledgeMailboxItem(itemId: id))
    }

    /// She opened the imported forms from the inbox.
    func markImportsSeen() {
        imports = []
        persist()
    }

    // MARK: - One item

    private func process(_ item: MailboxItem) async {
        var envelope = item.envelope
        if envelope == nil {
            do {
                envelope = try await repository.mailboxItem(id: item.id).envelope
            } catch {
                errorMessage = BookingSyncService.text(for: error)
                return
            }
        }
        guard let envelope, envelope.itemId == item.id else { return record(item, .openFailed) }
        guard envelope.isSupported, let kind = envelope.mailboxKind else { return record(item, .unsupported) }
        let privateKey: Curve25519.KeyAgreement.PrivateKey?
        do {
            privateKey = try keys.inboxPrivateKey(forKeyID: envelope.keyId)
        } catch {
            // Locked: not a failure of the item, try again next sync.
            return
        }
        guard let privateKey else { return record(item, .unknownKey) }
        let plaintext: Data
        do {
            plaintext = try EnvelopeOpener.open(envelope, with: privateKey)
        } catch {
            return record(item, .openFailed)
        }
        switch kind {
        case .intake:
            await importIntake(plaintext, item: item)
        case .checkin, .datarequest:
            guard let message = MailboxMessage.decode(
                plaintext, kind: kind, id: item.id, bookingId: item.bookingId, receivedAt: item.createdAt
            ) else { return record(item, .badPayload) }
            messages.append(message)
            forget(item.id)
        }
    }

    private func importIntake(_ plaintext: Data, item: MailboxItem) async {
        guard let payload = try? IntakePayload.decode(plaintext) else { return record(item, .badPayload) }
        guard let repository = vault.repository else { return }
        do {
            guard let clientID = try await clientID(for: payload, item: item) else { return record(item, .unmatched) }
            let version: Int
            if let known = payload.formVersion {
                version = known
            } else {
                version = HealthFormTemplateRules.current(of: try await repository.healthFormTemplates())?.version ?? 1
            }
            let form = HealthForm(
                id: UUID(), clientID: clientID, formVersion: version, filledBy: .client,
                isForMinor: payload.isForMinor, signedAt: payload.submittedAt ?? item.createdAt,
                importedFromItemID: item.id, answers: payload.answers, minorName: payload.minorName
            )
            let imported = try await repository.importHealthForm(form)
            forget(item.id)
            queue.enqueue(.acknowledgeMailboxItem(itemId: item.id))
            guard imported else { return }
            imports.append(HealthFormImport(id: item.id, clientID: clientID, formID: form.id, at: now()))
            persist()
            await notifier.post(
                id: "bello.mailbox.\(item.id)", threadID: "bello.mailbox",
                title: String(localized: "push.mailbox.form.title", defaultValue: "Health form received"),
                body: String(localized: "push.mailbox.form.body", defaultValue: "A client sent her health form.")
            )
        } catch {
            errorMessage = BookingSyncService.text(for: error)
        }
    }

    /// The booking the form answers names the client by phone; a schema-1 form from a booking the phone no longer
    /// has may still match by the name it carried.
    private func clientID(for payload: IntakePayload, item: MailboxItem) async throws -> UUID? {
        guard let repository = vault.repository else { return nil }
        let clients = try await repository.allClients()
        let bookingID = payload.bookingId.isEmpty ? item.bookingId : payload.bookingId
        if let booking = bookings.snapshot.booking(id: bookingID) {
            let phone = booking.client.phone.trimmingCharacters(in: .whitespaces)
            if let match = clients.first(where: { $0.phoneE164?.trimmingCharacters(in: .whitespaces) == phone }) {
                return match.id
            }
            // Confirmed bookings are mirrored by the sync; one that is still a request has no client yet.
            return nil
        }
        let visits = try await repository.loadAppointments(in: Self.anyTime)
        if let visit = visits.first(where: { $0.bookingID == bookingID }) { return visit.clientID }
        if let name = payload.clientName {
            let matches = clients.filter {
                $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
            if matches.count == 1 { return matches[0].id }
        }
        return nil
    }

    private func record(_ item: MailboxItem, _ reason: UndecryptableItem.Reason) {
        undecryptable.removeAll { $0.id == item.id }
        undecryptable.append(UndecryptableItem(id: item.id, kind: item.kind, reason: reason, at: now()))
        persist()
    }

    private func forget(_ id: String) {
        guard undecryptable.contains(where: { $0.id == id }) else { return }
        undecryptable.removeAll { $0.id == id }
        persist()
    }

    private static let anyTime = DateInterval(start: Date(timeIntervalSince1970: 0), end: .distantFuture)

    // MARK: - Storage (ids and times only)

    private struct Stored: Codable {
        var undecryptable: [UndecryptableItem] = []
        var imports: [HealthFormImport] = []
    }

    private func persist() {
        guard let userID else { return }
        let stored = Stored(undecryptable: undecryptable, imports: imports)
        defaults.set(try? JSONEncoder().encode(stored), forKey: Self.key(userID))
    }

    private static func load(_ defaults: UserDefaults, key: String) -> Stored? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Stored.self, from: data)
    }

    private static func key(_ userID: String) -> String { DefaultsKey.mailboxUndecryptable + "." + userID }
}
