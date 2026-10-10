//
//  NewAppointmentClientCard.swift
//  BelloHub
//

import SwiftUI

/// The client picker of New appointment: a search field, a handful of clients (the chosen one first) and "New client".
/// A card of plain rows rather than a `List`, because it sits inside the sheet's scroll view.
struct NewAppointmentClientCard: View {
    let clients: [Client]
    let selectedID: UUID?
    let hasLoaded: Bool
    @Binding var searchText: String
    let onSelect: (UUID) -> Void
    let onNewClient: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            ForEach(Array(clients.enumerated()), id: \.element.id) { index, client in
                Divider().overlay(Palette.hairline)
                row(client, index: index)
            }
            if clients.isEmpty && hasLoaded {
                Divider().overlay(Palette.hairline)
                Text("newAppointment.client.none")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .padding(Spacing.md)
                    .accessibilityIdentifier("newAppointment.client.none")
            }
            Divider().overlay(Palette.hairline)
            Button(action: onNewClient) { AddRowLabel(title: "newAppointment.client.new") }
                .padding(.horizontal, Spacing.md)
                .accessibilityIdentifier("newAppointment.client.newButton")
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.hairline)
        }
    }

    // MARK: - Parts

    private var searchField: some View {
        HStack(spacing: Spacing.row) {
            Image(icon: .search).foregroundStyle(Palette.ink2).accessibilityHidden(true)
            TextField(text: $searchText, prompt: Text.prompt("newAppointment.client.search")) {
                Text("newAppointment.client.search")
            }
                .font(Typography.body)
                .foregroundStyle(Palette.ink)
                .autocorrectionDisabled()
                .accessibilityIdentifier("newAppointment.client.searchField")
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 52)
    }

    private func row(_ client: Client, index: Int) -> some View {
        let isSelected = client.id == selectedID
        return Button { onSelect(client.id) } label: {
            HStack(spacing: Spacing.row) {
                Avatar(name: client.name, id: client.id.uuidString, size: 40)
                Text(verbatim: client.name)
                    .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Spacing.sm)
                if isSelected {
                    Image(icon: .check)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.onAction)
                        .frame(width: 28, height: 28)
                        .background(Palette.action, in: Circle())
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("newAppointment.client.\(index)")
    }
}
