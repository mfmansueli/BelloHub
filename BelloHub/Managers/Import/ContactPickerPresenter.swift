//
//  ContactPickerPresenter.swift
//  BelloHub
//

import SwiftUI

/// Presents `ContactPickerSheet` while `importer.isPickerPresented` is true. The binding closes the importer's
/// pending request when she swipes the sheet away, so a waiting `pickContacts()` always returns.
struct ContactPickerPresenter: ViewModifier {
    let importer: any ContactsImporting

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(
            get: { importer.isPickerPresented },
            set: { isPresented in if !isPresented, importer.isPickerPresented { importer.finishPicking(nil) } }
        )) {
            ContactPickerSheet { importer.finishPicking($0) }
                .ignoresSafeArea()
        }
    }
}

extension View {
    /// Shows the system contact picker whenever `importer` asks for it.
    func contactPicker(for importer: any ContactsImporting) -> some View {
        modifier(ContactPickerPresenter(importer: importer))
    }
}
