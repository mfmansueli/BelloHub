//
//  ClientsPreviewHost.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// Builds a `ClientsPreviewWorld` once and hands it to the preview's content, with the Services in the environment.
struct ClientsPreviewHost<Content: View>: View {
    @State private var world: ClientsPreviewWorld?
    @ViewBuilder let content: (ClientsPreviewWorld) -> Content

    var body: some View {
        Group {
            if let world {
                content(world)
                    .environment(world.profile)
                    .environment(world.vault)
                    .environment(world.registration)
            } else {
                ProgressView()
            }
        }
        .task { world = await ClientsPreviewWorld.make() }
    }
}
#endif
