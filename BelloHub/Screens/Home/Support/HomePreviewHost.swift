//
//  HomePreviewHost.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// Builds the calendar preview world once (demo clients and visits over an in-memory vault) and puts every Service the
/// Home, Alerts, Follow-ups and Win back screens read in the environment. DEBUG only, like the in-memory vault.
struct HomePreviewHost<Content: View>: View {
    @State private var world: CalendarPreviewWorld?
    @State private var digest: AgendaDigestService?
    @State private var inbox: BookingSyncService?
    @State private var mailbox: MailboxService?
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if let world, let digest, let inbox, let mailbox {
                content()
                    .environment(world.vault)
                    .environment(world.profile)
                    .environment(world.registration)
                    .environment(world.appointments)
                    .environment(world.timeBlocks)
                    .environment(world.bookingSetup)
                    .environment(MessageService(vault: world.vault))
                    .environment(PermissionService(provider: UITestPermissionProvider()))
                    .environment(digest)
                    .environment(inbox)
                    .environment(mailbox)
                    .environment(FollowUpQueueService(defaults: .standard, vault: world.vault))
                    .environment(MainNavigation())
            } else {
                ProgressView()
            }
        }
        .task {
            let built = await CalendarPreviewWorld.make()
            world = built
            digest = built.map {
                AgendaDigestService(appointments: $0.appointments, timeBlocks: $0.timeBlocks, vault: $0.vault)
            }
            let offline = OfflineInboxRepository()
            let queue = OutboundQueue(repository: offline)
            let sync = built.map {
                BookingSyncService(
                    repository: offline, queue: queue, appointments: $0.appointments, vault: $0.vault, pollInterval: nil
                )
            }
            inbox = sync
            if let built, let sync {
                mailbox = MailboxService(
                    repository: offline, keys: KeyManager(), vault: built.vault, queue: queue, bookings: sync,
                    notifier: UITestNotificationPoster()
                )
            }
        }
    }
}
#endif
