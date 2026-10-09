//
//  ProductsView.swift
//  BelloHub
//

import SwiftUI

/// 6.4 Products: the entry More (and Services) push. It only reads the Services from the environment and hands them to
/// `ProductsContentView`, which owns the ViewModel (the same split as `ServicesView`).
struct ProductsView: View {
    @Environment(VaultService.self) private var vault

    init() {}

    var body: some View {
        ProductsContentView(repository: vault.repository)
    }
}

#if DEBUG
#Preview {
    let vault = VaultService(repository: InMemoryClientRecordRepository())
    return NavigationStack { ProductsView() }
        .environment(vault)
}
#endif
