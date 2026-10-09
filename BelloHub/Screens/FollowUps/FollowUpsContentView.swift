//
//  FollowUpsContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of Follow-ups: one card per client whose return date has arrived (Message, Book) and the birthdays of the
/// week (Send wishes). Every message opens as a sheet with the text ready; nothing is sent by the app (D14).
struct FollowUpsContentView: View {
    @State private var viewModel: FollowUpsViewModel
    @State private var agendaSheet: AgendaSheet?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    init(viewModel: FollowUpsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var formatters: Formatters { viewModel.settings.formatters(locale: locale) }

    var body: some View {
        ScrollView {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: Spacing.row) {
                    Text("followUps.subtitle")
                        .font(Typography.body).foregroundStyle(Palette.ink2)
                        .accessibilityIdentifier("followUps.subtitle")
                    ScreenStateView(
                        phase: viewModel.phase(now: context.date), prefix: "followUps", retry: viewModel.retry
                    ) {
                        EmptyState(
                            icon: .repeatArrows, title: "followUps.empty.title", message: "followUps.empty.message"
                        )
                        .accessibilityIdentifier("followUps.empty")
                    } content: {
                        sections(viewModel.list(now: context.date), now: context.date)
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.bg)
        .navigationTitle(Text("followUps.title"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.refreshAsync() }
        .task { viewModel.start() }
        .agendaSheet(item: $agendaSheet)
    }

    // MARK: - Sections

    @ViewBuilder
    private func sections(_ list: FollowUpsList, now: Date) -> some View {
        ForEach(list.due) { row in dueCard(row) }
        if !list.birthdays.isEmpty {
            SectionHeader(title: "followUps.birthdays.title")
            ListCard(dividerInset: Spacing.md) {
                ForEach(list.birthdays) { row in birthdayRow(row) }
            }
        }
    }

    private func dueCard(_ row: FollowUpsList.DueRow) -> some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            HStack(spacing: Spacing.row) {
                Avatar(name: row.client.name, id: row.client.id.uuidString, size: 52)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: row.client.name)
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(verbatim: "\(row.followUp.serviceName) · "
                         + formatters.daysAgo(row.followUp.daysSinceLastVisit))
                        .font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("followUps.row.\(row.client.id.uuidString)")
            Text(LocalizedStringResource(
                "followUps.row.dueSince",
                defaultValue: "Return due since \(formatters.weekdayDayMonth(row.followUp.dueSince))"
            ).localized(in: locale))
                .font(Typography.footnote).foregroundStyle(Palette.ink2)
            actions(row)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
    }

    private func actions(_ row: FollowUpsList.DueRow) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.sm))
        return layout {
            Button { agendaSheet = .clientMessage(viewModel.message(for: row)) } label: {
                if viewModel.wasOpened(row.client.id) {
                    Label { Text("followUps.message.opened") } icon: { Image(icon: .check) }
                } else {
                    Text("followUps.message")
                }
            }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("followUps.message.\(row.client.id.uuidString)")
            Button { agendaSheet = .newAppointment(clientID: row.client.id, startsAt: nil) } label: {
                Text("followUps.book")
            }
            .buttonStyle(.belloPrimary)
            .accessibilityIdentifier("followUps.book.\(row.client.id.uuidString)")
        }
    }

    private func birthdayRow(_ row: FollowUpsList.BirthdayRow) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.row))
        return layout {
            HStack(spacing: Spacing.row) {
                Avatar(name: row.client.name, id: row.client.id.uuidString, size: 44)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: row.client.name)
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(verbatim: row.birthday.isToday
                         ? String(localized: "appointment.today", locale: locale)
                         : formatters.weekdayDayMonth(row.birthday.date))
                        .font(Typography.footnote).foregroundStyle(Palette.ink2)
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: Spacing.sm) }
            }
            .accessibilityElement(children: .combine)
            Button { agendaSheet = .clientMessage(viewModel.wishes(for: row)) } label: {
                Text("followUps.wishes")
            }
            .buttonStyle(.belloChip(selected: false))
            .accessibilityIdentifier("followUps.wishes.\(row.client.id.uuidString)")
        }
        .padding(Spacing.md)
        .frame(minHeight: 64)
    }
}
