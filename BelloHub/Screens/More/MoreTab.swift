//
//  MoreTab.swift
//  BelloHub
//

import SwiftUI

/// The More tab: its own `NavigationStack` over a typed path, and the destination of every `MoreRoute`. `MainView`
/// puts this view in the tab and knows nothing else about the screens behind it.
struct MoreTab: View {
    let onSignOut: () -> Void

    @Environment(ProfileService.self) private var profile
    /// Optional so a preview of the shell that does not inject a vault still builds; the app always provides one.
    @Environment(VaultService.self) private var vault: VaultService?
    @State private var path: [MoreRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            MoreView(onSignOut: onSignOut)
                .navigationDestination(for: MoreRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: MoreRoute) -> some View {
        switch route {
        case .tags:
            TagsView(profile: profile, clients: vault?.repository)
        case .recordTemplate:
            RecordTemplateView(profile: profile)
        case .formTemplates:
            FormTemplatesView()
        }
    }
}

#Preview {
    MoreTab(onSignOut: {})
        .environment(ProfileService(vault: VaultService(repository: nil)))
        .environment(VaultService(repository: nil))
        .environment(AppLockService(keyManager: KeyManager()))
}
