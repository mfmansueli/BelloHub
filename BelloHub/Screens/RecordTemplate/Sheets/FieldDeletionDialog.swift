//
//  FieldDeletionDialog.swift
//  BelloHub
//

import SwiftUI

/// The confirmation before one of her own fields is deleted, shared by the swipe on the list and the delete button of
/// the field sheet. It says the field stops being asked and that what saved records hold stays, and it points to the
/// switch as the way to pause a field without deleting it.
private struct FieldDeletionDialog: ViewModifier {
    @Binding var field: RecordFieldSetting?
    let name: (RecordFieldSetting) -> String
    let onConfirm: (RecordFieldSetting) -> Void

    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text(LocalizedStringResource(
                "fieldEditor.delete.title", defaultValue: "Delete “\(field.map(name) ?? "")”?"
            ).localized(in: locale)),
            isPresented: Binding(get: { field != nil }, set: { if !$0 { field = nil } }),
            titleVisibility: .visible,
            presenting: field
        ) { field in
            Button(role: .destructive) { onConfirm(field) } label: { Text("fieldEditor.delete.confirm") }
                .accessibilityIdentifier("recordTemplate.deleteConfirmButton")
            Button(role: .cancel) {} label: { Text("common.cancel") }
        } message: { _ in
            Text("fieldEditor.delete.message")
        }
    }
}

extension View {
    /// Asks before deleting `field` (set it to a field to present the dialog); calls `onConfirm` when she agrees.
    func fieldDeletionDialog(
        _ field: Binding<RecordFieldSetting?>, name: @escaping (RecordFieldSetting) -> String,
        onConfirm: @escaping (RecordFieldSetting) -> Void
    ) -> some View {
        modifier(FieldDeletionDialog(field: field, name: name, onConfirm: onConfirm))
    }
}
