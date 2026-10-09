//
//  PushEvent.swift
//  BelloHub
//

import Foundation

/// A push as the app understands it (API.md section 7): a kind and an id, nothing else travels. `AppDelegate` posts
/// it as a `Notification`; `PushService` turns it into a sync.
struct PushEvent: Equatable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case booking
        case bookingLate
        case bookingConfirmed
        case rescheduleRequest
        case waitlist
        /// Silent: the app syncs the mailbox and raises its own alert.
        case mailbox
    }

    let kind: Kind
    let id: String?
    /// True when she tapped the notification (open the inbox), false for a delivery in the background.
    let wasOpened: Bool

    static let notificationName = Notification.Name("app.bellohub.push")
    static let userInfoKey = "event"

    /// From the FCM `data` payload (`kind`, `id`); nil when the payload is not ours.
    init?(userInfo: [AnyHashable: Any], wasOpened: Bool) {
        guard let raw = userInfo["kind"] as? String, let kind = Kind(rawValue: raw) else { return nil }
        self.kind = kind
        let id = userInfo["id"] as? String
        self.id = (id?.isEmpty ?? true) ? nil : id
        self.wasOpened = wasOpened
    }

    init(kind: Kind, id: String? = nil, wasOpened: Bool = false) {
        self.kind = kind
        self.id = id
        self.wasOpened = wasOpened
    }

    /// Posts the event to whoever listens (`PushService`, `MainView`).
    func post() {
        NotificationCenter.default.post(name: Self.notificationName, object: nil, userInfo: [Self.userInfoKey: self])
    }

    static func from(_ notification: Notification) -> PushEvent? {
        notification.userInfo?[userInfoKey] as? PushEvent
    }
}
