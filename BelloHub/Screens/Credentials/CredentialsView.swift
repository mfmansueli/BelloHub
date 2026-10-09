//
//  CredentialsView.swift
//  BelloHub
//

import SwiftUI

/// 6.10 Credentials: the entry More pushes. It only reads the Services from the environment and hands them to
/// `CredentialsContentView`, which owns the ViewModel (the same split as `ServicesView`).
struct CredentialsView: View {
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale

    init() {}

    var body: some View {
        CredentialsContentView(repository: vault.repository, profile: profile, locale: locale)
    }
}

#if DEBUG
#Preview {
    let vault = VaultService(repository: InMemoryClientRecordRepository())
    return NavigationStack { CredentialsView() }
        .environment(vault)
        .environment(ProfileService(vault: vault))
}
#endif
