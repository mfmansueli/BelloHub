//
//  AccountView.swift
//  BelloHub
//

import SwiftUI

/// 7.1 Account, as the More tab opens it. Reads the Services the screen needs from the environment and hands them to
/// `AccountContentView`, which owns the ViewModel (a View cannot read the environment in its `init`).
struct AccountView: View {
    let onSignOut: () -> Void

    @Environment(ProfileService.self) private var profile
    @Environment(AccountService.self) private var account
    @Environment(SessionService.self) private var session

    var body: some View {
        AccountContentView(profile: profile, account: account, session: session, onSignOut: onSignOut)
    }
}

#if DEBUG
#Preview {
    let vault = VaultService(repository: nil)
    let keys = KeyManager()
    NavigationStack { AccountView(onSignOut: {}) }
        .environment(ProfileService(vault: vault))
        .environment(AccountService(vault: vault, keyManager: keys, keyStore: InMemoryKeyStore()))
        .environment(SessionService(provider: LocalDevAuthProvider(defaults: .standard), defaults: .standard))
        .environment(DataExportService(vault: vault))
        .environment(BookingSetupService(vault: vault))
}
#endif
