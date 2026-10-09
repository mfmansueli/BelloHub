//
//  FormTemplatesView.swift
//  BelloHub
//

import SwiftUI

/// 6.14 FormTemplates: Client forms. The entry More pushes. It only reads the Services from the environment and hands
/// them to `FormTemplatesContentView`, which owns the ViewModel (the same split as `ClientHealthView`).
struct FormTemplatesView: View {
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale

    init() {}

    var body: some View {
        FormTemplatesContentView(repository: vault.repository, profile: profile, locale: locale)
    }
}

#if DEBUG
#Preview {
    let vault = VaultService(repository: InMemoryClientRecordRepository())
    return NavigationStack { FormTemplatesView() }
        .environment(vault)
        .environment(ProfileService(vault: vault))
}
#endif
