//
//  FormTemplatesView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 6.14 FormTemplates, which the health-forms slice builds with this exact signature. The coordinator
/// deletes this file at integration; the More tab and the Record fields screen already call `FormTemplatesView()`.
struct FormTemplatesView: View {
    init() {}

    var body: some View {
        EmptyState(
            icon: .document, title: "formTemplates.placeholder.title", message: "formTemplates.placeholder.message"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .navigationTitle(Text("more.row.forms"))
    }
}

#Preview {
    NavigationStack { FormTemplatesView() }
}
