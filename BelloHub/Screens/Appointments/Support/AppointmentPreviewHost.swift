//
//  AppointmentPreviewHost.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// Builds an `AppointmentPreviewWorld` once and hands it to the preview's content, with the Services in the
/// environment.
struct AppointmentPreviewHost<Content: View>: View {
    @State private var world: AppointmentPreviewWorld?
    @ViewBuilder let content: (AppointmentPreviewWorld) -> Content

    var body: some View {
        Group {
            if let world {
                content(world)
                    .environment(world.vault)
                    .environment(world.profile)
                    .environment(world.appointments)
                    .environment(world.setup)
                    .environment(world.messages)
            } else {
                ProgressView()
            }
        }
        .task { world = await AppointmentPreviewWorld.make() }
    }
}
#endif
