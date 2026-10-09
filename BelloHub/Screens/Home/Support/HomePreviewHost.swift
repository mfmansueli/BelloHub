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
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if let world, let digest {
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
        }
    }
}
#endif
