//
//  ClientInfoSection.swift
//  BelloHub
//

import SwiftUI

/// "Information": who she is and what the professional knows about her. Contact and personal details, the next
/// booking, what she remembers (preferences, sensitivities, recurring requests) and her private habits.
struct ClientInfoSection: View {
    let snapshot: ClientProfileSnapshot
    let formatters: Formatters
    let now: Date
    let onEditKnowledge: () -> Void
    let onEditDetails: () -> Void
    let onBook: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("clientRecord.info.details", action: "clientProfile.edit",
                   identifier: "clientRecord.info.editDetails", perform: onEditDetails)
            details
            header("clientProfile.next", action: "clientRecord.info.book", identifier: "clientRecord.info.book",
                   perform: onBook)
            nextBooking
            header("clientProfile.knowledge.title", action: "clientProfile.knowledge.edit",
                   identifier: "clientProfile.knowledgeEditButton", perform: onEditKnowledge)
            KnowledgeSummaryCard(client: snapshot.client)
            habitsHeader
            HabitsCard(habits: snapshot.habits, source: snapshot.client.source)
        }
        .accessibilityIdentifier("clientRecord.info")
    }

    // MARK: - Sections

    private var details: some View {
        let client = snapshot.client
        return ListCard(dividerInset: Spacing.md) {
            if let phone = client.phoneE164 {
                row("clientRecord.info.phone", value: BidiIsolate.wrapLeftToRight(phone))
            }
            if let email = client.email {
                row("clientRecord.info.email", value: BidiIsolate.wrapLeftToRight(email))
            }
            if let birthday = client.birthday {
                row("clientRecord.info.birthday", value: formatters.birthday(birthday))
            }
            row("clientRecord.info.since", value: formatters.shortDate(client.createdAt))
        }
        .accessibilityIdentifier("clientRecord.info.detailsCard")
    }

    private var nextBooking: some View {
        let next = snapshot.nextAppointment
        return VisitTile(
            title: "clientProfile.next",
            service: next?.serviceName,
            detail: next.map {
                formatters.dayAndTime(
                    $0.startsAt, now: now,
                    today: LocalizedStringResource("clientProfile.today").resolved(in: locale),
                    tomorrow: LocalizedStringResource("clientProfile.tomorrow").resolved(in: locale)
                )
            },
            emptyText: "clientProfile.next.empty",
            status: next.map { appointment in
                appointment.status == .confirmed
                    ? .init(label: "clientProfile.next.confirmed", style: StatusPalette.confirmed)
                    : .init(label: "clientProfile.next.booked", style: StatusPalette.pending)
            },
            identifier: "clientProfile.next"
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private var habitsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("clientProfile.habits.title")
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.row)
            Label { Text("clientProfile.habits.private") } icon: { Image(icon: .lock) }
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
        }
        .padding(.top, Spacing.section)
        .padding(.bottom, Spacing.row)
    }

    // MARK: - Pieces

    /// A section title with its action. Not a `SectionHeader`, because that one carries no identifier on its action.
    private func header(
        _ title: LocalizedStringKey, action: LocalizedStringKey, identifier: String, perform: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.row)
            Button(action: perform) {
                Text(action)
                    .font(Typography.metaStrong)
                    .foregroundStyle(Palette.roseText)
                    .frame(minHeight: Spacing.touchTarget)
            }
            .accessibilityIdentifier(identifier)
        }
        .padding(.top, Spacing.section)
        .padding(.bottom, Spacing.row)
    }

    /// Label and value side by side; stacked at the accessibility sizes, where two columns would squeeze both.
    private func row(_ label: LocalizedStringKey, value: String) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.md))
        return layout {
            Text(label).font(Typography.meta).foregroundStyle(Palette.ink2)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Spacing.sm) }
            Text(verbatim: value).font(Typography.body).foregroundStyle(Palette.ink)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, minHeight: Spacing.touchTarget, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .accessibilityElement(children: .combine)
    }
}
