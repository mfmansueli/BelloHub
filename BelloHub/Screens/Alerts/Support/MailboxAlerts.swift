//
//  MailboxAlerts.swift
//  BelloHub
//

import Foundation

/// The sealed-mailbox part of the Alerts tab (docs/06 section 3.5): what her clients sent through their links and the
/// phone opened (check-ins, copy and deletion requests), items that could not be opened or not matched yet, and the
/// health forms imported since she last looked. Every card ends with an action that acknowledges the item, so a
/// client's request is never left unanswered on the server. Oldest first. Pure.
struct MailboxAlerts: Equatable, Sendable {
    enum Item: Identifiable, Equatable, Sendable {
        case checkin(id: String, feeling: Feeling, note: String?, hasPhoto: Bool)
        case dataRequest(id: String, isDeletion: Bool, name: String, phone: String, note: String?)
        /// It did not open or did not read: the client has to send it again.
        case unopened(id: String)
        /// It opened, but no booking or client on the phone matches it yet; it is retried on every sync.
        case unmatched(id: String)

        var id: String {
            switch self {
            case .checkin(let id, _, _, _), .dataRequest(let id, _, _, _, _), .unopened(let id), .unmatched(let id): id
            }
        }

        /// Messages are marked handled; undecryptable items are dismissed (both acknowledge the server item).
        var isMessage: Bool {
            switch self {
            case .checkin, .dataRequest: true
            case .unopened, .unmatched: false
            }
        }
    }

    /// How she feels after the visit, as the page sends it; anything unknown reads as "okay".
    enum Feeling: String, Sendable {
        case good, okay, irritated, reaction
    }

    let items: [Item]
    /// Health forms imported and not yet seen.
    let importedCount: Int

    var isEmpty: Bool { items.isEmpty && importedCount == 0 }

    static let empty = MailboxAlerts(items: [], importedCount: 0)

    static func make(
        messages: [MailboxMessage], undecryptable: [UndecryptableItem], imports: [HealthFormImport]
    ) -> MailboxAlerts {
        let opened = messages.sorted { ($0.receivedAt, $0.id) < ($1.receivedAt, $1.id) }.map(item(for:))
        let failed = undecryptable.sorted { ($0.at, $0.id) < ($1.at, $1.id) }.map { entry -> Item in
            entry.reason == .unmatched ? .unmatched(id: entry.id) : .unopened(id: entry.id)
        }
        return MailboxAlerts(items: opened + failed, importedCount: imports.count)
    }

    private static func item(for message: MailboxMessage) -> Item {
        switch message.content {
        case .checkin(let feeling, let note, let photo):
            .checkin(
                id: message.id, feeling: Feeling(rawValue: feeling) ?? .okay, note: cleaned(note),
                hasPhoto: photo != nil
            )
        case .dataRequest(let request, let name, let phone, let note):
            .dataRequest(
                id: message.id, isDeletion: request == "delete", name: name, phone: phone, note: cleaned(note)
            )
        }
    }

    private static func cleaned(_ note: String?) -> String? {
        guard let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
