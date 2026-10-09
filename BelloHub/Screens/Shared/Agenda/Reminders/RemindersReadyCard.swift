//
//  RemindersReadyCard.swift
//  BelloHub
//

import SwiftUI

/// The "Reminders ready" list (D31), on Home and in Alerts: the visits whose client she can remind now, each with the
/// day and time, the service and a "Send" button that opens the message sheet. A reminder she already opened shows
/// "Opened" instead. The app never sends one by itself.
struct RemindersReadyCard: View {
    let items: [RemindersReady.Item]
    let formatters: Formatters
    let onSend: (RemindersReady.Item) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ListCard(dividerInset: Spacing.md) {
            ForEach(items) { item in row(item) }
        }
    }

    private func row(_ item: RemindersReady.Item) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.row))
        return layout {
            HStack(spacing: Spacing.row) {
                Avatar(name: item.client.name, id: item.client.id.uuidString, size: 44)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: item.client.name)
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(verbatim: "\(formatters.dateTime(item.appointment.startsAt)) · "
                         + item.appointment.serviceName)
                        .font(Typography.footnote).foregroundStyle(Palette.ink2)
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: Spacing.sm) }
            }
            .accessibilityElement(children: .combine)
            if item.openedAt == nil {
                Button { onSend(item) } label: { Text("reminders.send") }
                    .buttonStyle(.belloChip(selected: false))
                    .accessibilityIdentifier("reminders.send.\(item.appointment.id.uuidString)")
            } else {
                Label { Text("reminders.opened") } icon: { Image(icon: .check) }
                    .font(Typography.metaStrong)
                    .foregroundStyle(Palette.sageText)
                    .frame(minHeight: Spacing.touchTarget)
                    .accessibilityIdentifier("reminders.opened.\(item.appointment.id.uuidString)")
            }
        }
        .padding(Spacing.md)
        .frame(minHeight: 64)
    }
}
