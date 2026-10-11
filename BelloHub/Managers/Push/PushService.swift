//
//  PushService.swift
//  BelloHub
//

import Foundation
import Observation

/// Push for the signed-in professional: registers her device's token with the server (through the `OutboundQueue`,
/// so a token learned offline still gets there) and turns an incoming push (`PushEvent`, posted by `AppDelegate`)
/// into a sync of the bookings or of the sealed mailbox. The payload carries only a kind and an id (API.md section 7);
/// the text on the lock screen is the system's localized `loc-key`, never a name.
@MainActor
@Observable
final class PushService {
    /// The token the server knows, for this user.
    private(set) var registeredToken: String?
    /// The last push received, so the inbox can open on it.
    private(set) var lastEvent: PushEvent?

    @ObservationIgnored private let provider: any PushTokenProviding
    @ObservationIgnored private let queue: OutboundQueue
    @ObservationIgnored private let bookings: BookingSyncService
    @ObservationIgnored private let mailbox: MailboxService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let locale: @Sendable () -> String?
    @ObservationIgnored private var userID: String?
    @ObservationIgnored private var tokenTask: Task<Void, Never>?
    @ObservationIgnored private var eventTask: Task<Void, Never>?

    init(
        provider: any PushTokenProviding,
        queue: OutboundQueue,
        bookings: BookingSyncService,
        mailbox: MailboxService,
        defaults: UserDefaults = .standard,
        // The server writes her pushes in the language she reads the app in (not the iPhone-wide language list).
        locale: @escaping @Sendable () -> String? = { InterfaceLocale.localization.rawValue }
    ) {
        self.provider = provider
        self.queue = queue
        self.bookings = bookings
        self.mailbox = mailbox
        self.defaults = defaults
        self.locale = locale
    }

    // MARK: - Listening

    func startListening(userId: String) {
        guard userID != userId else { return }
        stopListening()
        userID = userId
        registeredToken = defaults.string(forKey: Self.key(userId))
        provider.registerForRemoteNotifications()
        tokenTask = Task { [weak self, provider] in
            for await token in provider.tokens() {
                guard !Task.isCancelled else { return }
                self?.didReceive(token: token)
            }
        }
        eventTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: PushEvent.notificationName) {
                guard !Task.isCancelled, let event = PushEvent.from(notification) else { continue }
                self?.handle(event)
            }
        }
    }

    func stopListening() {
        tokenTask?.cancel()
        eventTask?.cancel()
        tokenTask = nil
        eventTask = nil
        userID = nil
        lastEvent = nil
        registeredToken = nil
    }

    /// Sign-out: the server stops pushing to this phone for her.
    func clearForSignOut(userID: String) {
        if let token = defaults.string(forKey: Self.key(userID)) {
            queue.enqueue(.unregisterDevice(fcmToken: token))
            defaults.removeObject(forKey: Self.key(userID))
        }
        stopListening()
    }

    // MARK: - Events

    /// A push arrived (or was tapped). Public so a UI test or a debug hook can replay one.
    func handle(_ event: PushEvent) {
        lastEvent = event
        switch event.kind {
        case .mailbox: mailbox.syncNow()
        case .booking, .bookingLate, .bookingConfirmed, .rescheduleRequest, .waitlist: bookings.syncNow()
        }
    }

    /// She changed the interface language: the server is told again with the same token, so the pushes it writes
    /// follow. Nothing to do before a token is known.
    func interfaceLanguageDidChange() {
        guard userID != nil, let token = registeredToken else { return }
        queue.enqueue(.registerDevice(fcmToken: token, locale: locale()))
    }

    private func didReceive(token: String) {
        guard let userID, token != registeredToken else { return }
        registeredToken = token
        defaults.set(token, forKey: Self.key(userID))
        queue.enqueue(.registerDevice(fcmToken: token, locale: locale()))
    }

    private static func key(_ userID: String) -> String { DefaultsKey.pushRegisteredToken + "." + userID }
}
