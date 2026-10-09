//
//  TagDeletionDialog.swift
//  BelloHub
//

import SwiftUI

/// The confirmation before a tag is deleted, shared by the swipe on the list and the delete button of the tag sheet.
/// It says how many people lose the tag and that nobody is deleted with it, because the count is what makes the
/// action safe to confirm.
private struct TagDeletionDialog: ViewModifier {
    @Binding var tag: Tag?
    let clientCount: (Tag) -> Int?
    let onConfirm: (Tag) -> Void

    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text(LocalizedStringResource(
                "tags.delete.title", defaultValue: "Delete “\(tag?.name ?? "")”?"
            ).localized(in: locale)),
            isPresented: Binding(get: { tag != nil }, set: { if !$0 { tag = nil } }),
            titleVisibility: .visible,
            presenting: tag
        ) { tag in
            Button(role: .destructive) { onConfirm(tag) } label: { Text("tags.delete.confirm") }
                .accessibilityIdentifier("tags.deleteConfirmButton")
            Button(role: .cancel) {} label: { Text("common.cancel") }
        } message: { tag in
            message(for: tag)
        }
    }

    private func message(for tag: Tag) -> Text {
        switch clientCount(tag) {
        case .none:
            Text("tags.delete.messageUnknown")
        case .some(0):
            Text("tags.delete.messageNone")
        case .some(let count):
            Text(LocalizedStringResource(
                "tags.delete.message", defaultValue: "\(count) people will lose this tag. Your list stays as it is."
            ).localized(in: locale))
        }
    }
}

extension View {
    /// Asks before deleting `tag` (set it to a tag to present the dialog); calls `onConfirm` when she agrees.
    func tagDeletionDialog(
        _ tag: Binding<Tag?>, clientCount: @escaping (Tag) -> Int?, onConfirm: @escaping (Tag) -> Void
    ) -> some View {
        modifier(TagDeletionDialog(tag: tag, clientCount: clientCount, onConfirm: onConfirm))
    }
}
