//
//  MailboxAlertCards.swift
//  BelloHub
//

import SwiftUI

/// The "From your clients" section of Alerts: check-ins and copy or deletion requests the phone opened from the sealed
/// mailbox, the items that could not be opened or matched, and the health forms added since she last looked. Each card
/// has one action that clears it and acknowledges it on the server (`MailboxAlerts`). The client's own words (her
/// note, the name and phone she typed) are shown as she wrote them, inside the app only, never on the lock screen.
struct MailboxAlertCards: View {
    let alerts: MailboxAlerts
    let onResolve: (MailboxAlerts.Item) -> Void
    let onImportsSeen: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        SectionHeader(title: "alerts.section.fromClients").motionRow()
        if alerts.importedCount > 0 { importsCard.motionRow() }
        ForEach(alerts.items) { item in card(item).motionRow() }
    }

    private var importsCard: some View {
        AlertCard(
            icon: .document, tone: .sage, title: Text("alerts.mailbox.imported.title"),
            message: Text(LocalizedStringResource(
                "alerts.mailbox.imported.message",
                defaultValue: "Added to your clients' records: \(alerts.importedCount)"
            ).localized(in: locale)),
            identifier: "alerts.mailbox.imported"
        ) {
            Button(action: onImportsSeen) { Text("alerts.mailbox.imported.done") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("alerts.mailbox.imported.action")
        }
    }

    @ViewBuilder
    private func card(_ item: MailboxAlerts.Item) -> some View {
        switch item {
        case .checkin(let id, let feeling, let note, let photo):
            AlertCard(
                icon: .chat, tone: feeling == .reaction || feeling == .irritated ? .rose : .sage,
                title: Text("alerts.mailbox.checkin.title"),
                message: Text(verbatim: lines([feelingText(feeling), quoted(note)])),
                identifier: "alerts.mailbox.\(id)"
            ) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if let photo { checkinPhoto(photo, id: id) }
                    resolveButton(item, label: "alerts.mailbox.handled")
                }
            }
        case .dataRequest(let id, let isDeletion, let name, let phone, let note):
            AlertCard(
                icon: .shield, tone: .peach,
                title: Text(isDeletion ? "alerts.mailbox.delete.title" : "alerts.mailbox.copy.title"),
                message: Text(verbatim: lines([requestText(name: name, phone: phone), quoted(note)])),
                identifier: "alerts.mailbox.\(id)"
            ) { resolveButton(item, label: "alerts.mailbox.handled") }
        case .unopened(let id):
            AlertCard(
                icon: .alert, tone: .rose, title: Text("alerts.mailbox.unopened.title"),
                message: Text("alerts.mailbox.unopened.message"), identifier: "alerts.mailbox.\(id)"
            ) { resolveButton(item, label: "alerts.mailbox.dismiss") }
        case .unmatched(let id):
            AlertCard(
                icon: .document, tone: .peach, title: Text("alerts.mailbox.unmatched.title"),
                message: Text("alerts.mailbox.unmatched.message"), identifier: "alerts.mailbox.\(id)"
            ) { resolveButton(item, label: "alerts.mailbox.dismiss") }
        }
    }

    /// Her photo, as the client sent it, inside the app only. It lives in memory with the message (the sealed envelope
    /// was opened on this iPhone) and is gone when the card is handled; nothing is written to disk.
    private func checkinPhoto(_ data: Data, id: String) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .overlay { DataImage(data: data) }
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .accessibilityElement()
            .accessibilityLabel(Text("alerts.mailbox.checkin.photoLabel"))
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier("alerts.mailbox.\(id).photo")
    }

    private func resolveButton(_ item: MailboxAlerts.Item, label: LocalizedStringKey) -> some View {
        Button { onResolve(item) } label: { Text(label) }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("alerts.mailbox.\(item.id).action")
    }

    // MARK: - Words

    private func feelingText(_ feeling: MailboxAlerts.Feeling) -> String {
        let resource: LocalizedStringResource = switch feeling {
        case .good: LocalizedStringResource("alerts.mailbox.checkin.good", defaultValue: "Feeling good.")
        case .okay: LocalizedStringResource("alerts.mailbox.checkin.okay", defaultValue: "Feeling okay.")
        case .irritated: LocalizedStringResource("alerts.mailbox.checkin.irritated", defaultValue: "Some irritation.")
        case .reaction: LocalizedStringResource("alerts.mailbox.checkin.reaction", defaultValue: "Reports a reaction.")
        }
        return resource.resolved(in: locale)
    }

    private func requestText(name: String, phone: String) -> String {
        LocalizedStringResource(
            "alerts.mailbox.request.message",
            defaultValue: """
            From \(BidiIsolate.wrap(name)), \(BidiIsolate.wrapLeftToRight(phone)). Export or delete the data from \
            the client's profile, then mark this as handled.
            """
        ).resolved(in: locale)
    }

    /// Her note as she wrote it, in quotes.
    private func quoted(_ note: String?) -> String? {
        note.map { "“\($0)”" }
    }

    private func lines(_ parts: [String?]) -> String {
        parts.compactMap { $0 }.joined(separator: "\n")
    }
}
