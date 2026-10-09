//
//  ServicesView.swift
//  BelloHub
//

import SwiftUI

/// 6.1 Services: the entry More pushes. It only reads the Services from the environment and hands them to
/// `ServicesContentView`, which owns the ViewModel (the same split as `FormTemplatesView`).
struct ServicesView: View {
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale

    init() {}

    var body: some View {
        ServicesContentView(repository: vault.repository, profile: profile, locale: locale)
    }
}

#if DEBUG
#Preview {
    let vault = VaultService(repository: InMemoryClientRecordRepository())
    return NavigationStack { ServicesView() }
        .environment(vault)
        .environment(ProfileService(vault: vault))
}
#endif
