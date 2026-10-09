//
//  WinBackContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of Win back: who has not been back for two months, with one friendly message each. "A short, friendly
/// message often brings people back. Nothing is sent until you tap Send."
struct WinBackContentView: View {
    @State private var viewModel: WinBackViewModel
    @State private var agendaSheet: AgendaSheet?
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    init(viewModel: WinBackViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var formatters: Formatters { viewModel.settings.formatters(locale: locale) }

    var body: some View {
        ScrollView {
            TimelineView(.everyMinute) { context in
                VStack(alignment: .leading, spacing: Spacing.row) {
                    Text("winBack.subtitle")
                        .font(Typography.body).foregroundStyle(Palette.ink2)
                        .accessibilityIdentifier("winBack.subtitle")
                    ScreenStateView(
                        phase: viewModel.phase(now: context.date), prefix: "winBack", retry: viewModel.retry
                    ) {
                        EmptyState(icon: .repeatArrows, title: "winBack.empty.title", message: "winBack.empty.message")
                            .accessibilityIdentifier("winBack.empty")
                    } content: {
                        rows(viewModel.list(now: context.date))
                    }
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.bottom, Spacing.lg)
        }
        .background(Palette.bg)
        .navigationTitle(Text("winBack.title"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.refreshAsync() }
        .task { viewModel.start() }
        .agendaSheet(item: $agendaSheet)
    }

    // MARK: - Rows

    @ViewBuilder
    private func rows(_ list: WinBackList) -> some View {
        let count = list.rows.count
        let noun = count == 1
            ? profile.clientTerm.singularText(in: locale) : profile.clientTerm.pluralText(in: locale)
        Text(LocalizedStringResource(
            "winBack.summary", defaultValue: "\(count) \(BidiIsolate.wrap(noun)) to reconnect"
        ).localized(in: locale))
            .font(Typography.section).foregroundStyle(Palette.ink)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("winBack.summary")
        ListCard(dividerInset: Spacing.md) {
            ForEach(list.rows) { row in rowView(row) }
        }
        FooterNote(text: "winBack.footer", icon: .info).padding(.top, Spacing.xs)
    }

    private func rowView(_ row: WinBackList.Row) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.row))
        return layout {
            HStack(spacing: Spacing.row) {
                Avatar(name: row.client.name, id: row.client.id.uuidString, size: 48)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: row.client.name)
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(LocalizedStringResource(
                        "winBack.row.lastVisit",
                        defaultValue: "Last visit \(formatters.daysAgo(row.candidate.daysSinceLastVisit))"
                    ).localized(in: locale))
                        .font(Typography.footnote).foregroundStyle(Palette.ink2)
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: Spacing.sm) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("winBack.row.\(row.client.id.uuidString)")
            Button { agendaSheet = .clientMessage(viewModel.message(for: row)) } label: {
                if viewModel.wasOpened(row.client.id) {
                    Label { Text("winBack.opened") } icon: { Image(icon: .check) }
                } else {
                    Text("winBack.message")
                }
            }
            .buttonStyle(.belloChip(selected: false))
            .accessibilityIdentifier("winBack.message.\(row.client.id.uuidString)")
        }
        .padding(Spacing.md)
        .frame(minHeight: 64)
    }
}
