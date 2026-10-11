//
//  DeletionDialog.swift
//  BelloHub
//

import SwiftUI

/// The confirmation before something she made is deleted, shared by the swipe on a list and the delete button of
/// its sheet. The caller writes the title and the message (they name the item and say what stays), so the dialog has
/// no wording of its own; it only makes sure nothing is deleted without a second tap.
private struct DeletionDialog<Item: Identifiable>: ViewModifier {
    @Binding var item: Item?
    let title: (Item) -> Text
    let message: (Item) -> Text
    let confirm: DeletionConfirm
    let onConfirm: (Item) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            item.map(title) ?? Text(verbatim: ""),
            isPresented: Binding(get: { item != nil }, set: { if !$0 { item = nil } }),
            titleVisibility: .visible,
            presenting: item
        ) { item in
            Button(role: .destructive) { onConfirm(item) } label: { Text(confirm.title) }
                .accessibilityIdentifier(confirm.identifier)
            Button(role: .cancel) {} label: { Text("common.cancel") }
        } message: { item in
            message(item)
        }
    }
}

extension View {
    /// Asks before deleting `item` (set it to an item to present the dialog); calls `onConfirm` when she agrees.
    func deletionDialog<Item: Identifiable>(
        _ item: Binding<Item?>,
        title: @escaping (Item) -> Text,
        message: @escaping (Item) -> Text,
        confirm: DeletionConfirm,
        onConfirm: @escaping (Item) -> Void
    ) -> some View {
        modifier(DeletionDialog(item: item, title: title, message: message, confirm: confirm, onConfirm: onConfirm))
    }
}
