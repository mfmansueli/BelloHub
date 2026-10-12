//
//  ClientPickerSheet.swift
//  BelloHub
//

import SwiftUI

/// "Register visit" from Home: she picks the client (search by name, tag or phone, the client list's own rule), then
/// the visit form opens for her with no booking, as a walk-in or an earlier visit written now. Archived clients are
/// not offered. Reads the clients `AgendaDigestService` already holds; nothing clinical is shown or searched.
struct ClientPickerSheet: View {
    let onPick: (Client) -> Void
    @Environment(AgendaDigestService.self) private var digest
    @Environment(ProfileService.self) private var profile
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var clients: [Client] {
        ClientSearch.filter(
            digest.clients.filter { !$0.isArchived }, query: query, tags: profile.tags, client: { $0 }
        )
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bg)
                .navigationTitle(Text("clientPicker.title"))
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, prompt: Text("clientPicker.search"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("common.cancel") }
                            .accessibilityIdentifier("clientPicker.cancelButton")
                    }
                }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    @ViewBuilder
    private var content: some View {
        if clients.isEmpty {
            EmptyState(
                icon: .user,
                title: query.isEmpty ? "clientPicker.empty.title" : "clientPicker.noMatch.title",
                message: query.isEmpty ? "clientPicker.empty.message" : "clientPicker.noMatch.message"
            )
            .padding(.horizontal, Spacing.gutter)
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("clientPicker.empty")
        } else {
            List(clients) { client in
                Button { pick(client) } label: { row(client) }
                    .listRowBackground(Palette.surface)
                    .accessibilityIdentifier("clientPicker.client.\(client.id.uuidString)")
            }
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("clientPicker.list")
        }
    }

    private func row(_ client: Client) -> some View {
        HStack(spacing: Spacing.row) {
            Avatar(name: client.name, id: client.id.uuidString, size: 36)
            Text(verbatim: client.name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            Spacer(minLength: Spacing.sm)
        }
        .frame(minHeight: Spacing.touchTarget)
        .contentShape(Rectangle())
    }

    private func pick(_ client: Client) {
        dismiss()
        onPick(client)
    }
}
