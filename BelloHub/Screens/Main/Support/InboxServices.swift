//
//  InboxServices.swift
//  BelloHub
//

import Foundation

/// The inbox Services (outbound queue, booking sync, mailbox, push, client links) of one session. They depend on each
/// other in a fixed order, so `AppDependencies` builds them together here instead of repeating the wiring in each
/// factory.
@MainActor
struct InboxServices {
    let queue: OutboundQueue
    let bookings: BookingSyncService
    let mailbox: MailboxService
    let push: PushService
    /// Deleting a client's data on the phone and, through the queue, on the server.
    let clientDeletion: ClientDataDeletionService
    /// The client's own link to change or cancel, for the messages she sends.
    let clientLinks: ClientLinkService

    /// Wires the Services over one inbox server. The defaults are the live ones; UI tests pass short retry delays, no
    /// polling and a notifier that never asks iOS.
    static func make(
        repository: any InboxRepository, keys: KeyManager, vault: VaultService, appointments: AppointmentService,
        pushProvider: any PushTokenProviding, defaults: UserDefaults = .standard,
        retryDelays: [Duration] = [.seconds(15), .seconds(60), .seconds(300)], pollInterval: Duration? = .seconds(90),
        notifier: any ImmediateNotifying = UserNotificationPoster()
    ) -> InboxServices {
        let queue = OutboundQueue(repository: repository, defaults: defaults, retryDelays: retryDelays)
        let bookings = BookingSyncService(
            repository: repository, queue: queue, appointments: appointments, vault: vault, defaults: defaults,
            pollInterval: pollInterval
        )
        let mailbox = MailboxService(
            repository: repository, keys: keys, vault: vault, queue: queue, bookings: bookings, notifier: notifier,
            defaults: defaults
        )
        let push = PushService(
            provider: pushProvider, queue: queue, bookings: bookings, mailbox: mailbox, defaults: defaults
        )
        return InboxServices(
            queue: queue, bookings: bookings, mailbox: mailbox, push: push,
            clientDeletion: ClientDataDeletionService(vault: vault, queue: queue),
            clientLinks: ClientLinkService(repository: repository)
        )
    }
}
