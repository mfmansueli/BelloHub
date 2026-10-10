//
//  ClientDeleteDataRow.swift
//  BelloHub
//

import SwiftUI

/// "Delete data" at the end of 4.3 ClientEdit (D30, product rule 8): when a client asks to be forgotten, everything of
/// hers leaves this iPhone at once and the booking server is told to forget her too (queued, so it reaches the server
/// even if the phone is offline now). Its own file because it owns its confirmation, progress and error.
struct ClientDeleteDataRow: View {
    let clientID: UUID
    /// Her first name, for the confirmation ("Delete the data of Ana?").
    let firstName: String
    let onDeleted: () -> Void

    @State private var confirms = false
    @State private var failed = false
    @Environment(ClientDataDeletionService.self) private var deletion
    @Environment(\.locale) private var locale

    var body: some View {
        ActionRow(
            icon: .trash, title: "clientEdit.deleteData.title", subtitle: Text("clientEdit.deleteData.subtitle"),
            tone: .coral, showsChevron: false, identifier: "clientEdit.deleteDataRow", action: { confirms = true }
        )
        .disabled(deletion.isDeleting)
        .confirmationDialog(dialogTitle, isPresented: $confirms, titleVisibility: .visible) {
            Button(role: .destructive, action: delete) { Text("clientEdit.deleteData.confirm") }
                .accessibilityIdentifier("clientEdit.deleteDataConfirmButton")
            Button(role: .cancel) {} label: { Text("common.cancel") }
        } message: {
            Text("clientEdit.deleteData.dialogMessage")
        }
        .alert(Text("clientEdit.deleteData.error"), isPresented: $failed) {
            Button(role: .cancel) {} label: { Text("common.close") }
        }
    }

    private var dialogTitle: Text {
        Text(LocalizedStringResource(
            "clientEdit.deleteData.dialogTitle", defaultValue: "Delete the data of \(BidiIsolate.wrap(firstName))?"
        ).localized(in: locale))
    }

    private func delete() {
        Task {
            do {
                try await deletion.deleteClientData(clientID: clientID)
                onDeleted()
            } catch {
                failed = true
            }
        }
    }
}
