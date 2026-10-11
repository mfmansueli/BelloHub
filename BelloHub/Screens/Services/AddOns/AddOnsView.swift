//
//  AddOnsView.swift
//  BelloHub
//

import SwiftUI

/// 6.3 AddOns: pushed from Services. It only reads the Services from the environment and hands them to
/// `AddOnsContentView`, which owns the ViewModel (the same split as `ServicesView`).
struct AddOnsView: View {
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale

    init() {}

    var body: some View {
        AddOnsContentView(repository: vault.repository, profile: profile, locale: locale)
    }
}

#if DEBUG
#Preview {
    let vault = VaultService(repository: InMemoryClientRecordRepository())
    return NavigationStack { AddOnsView() }
        .environment(vault)
        .environment(ProfileService(vault: vault))
}
#endif
