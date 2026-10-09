//
//  NoShowHistoryContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 4.11: her count under the rule, the missed visits and late cancellations behind it, forgiving a
/// miss, and starting her count from zero (which also opens online booking for her again). The history is never
/// deleted.
struct NoShowHistoryContentView: View {
    @State private var viewModel: NoShowHistoryViewModel
    @State private var confirmsReset = false
    @Environment(\.locale) private var locale
    @Environment(BookingSetupService.self) private var setup

    init(
        clientID: UUID, vault: VaultService, appointments: AppointmentService, profile: ProfileService,
        setup: BookingSetupService
    ) {
        _viewModel = State(initialValue: NoShowHistoryViewModel(
            clientID: clientID, vault: vault, appointments: appointments, profile: profile, setup: setup
        ))
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("noShowHistory.title"))
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.loadAsync() }
            .confirmationDialog(
                Text("noShowHistory.reset.confirmTitle"), isPresented: $confirmsReset, titleVisibility: .visible
            ) {
                Button { viewModel.resetCount() } label: { Text("noShowHistory.reset.confirm") }
                    .accessibilityIdentifier("noShowHistory.resetConfirmButton")
                Button(role: .cancel) {} label: { Text("common.cancel") }
            } message: {
                Text("noShowHistory.reset.confirmMessage")
            }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if let client = viewModel.client, let status = viewModel.status {
            overview(client: client, status: status)
        } else {
            VisitStateView(
                prefix: "noShowHistory", isMissing: viewModel.isMissing, errorMessage: viewModel.errorMessage,
                retry: viewModel.load
            )
        }
    }

    // MARK: - Overview

    private func overview(client: Client, status: NoShowStatus) -> some View {
        let name = client.name.split(separator: " ").first.map(String.init) ?? client.name
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                heading(client)
                if let message = viewModel.actionErrorMessage {
                    ErrorNotice(
                        message: message, actionTitle: "appointment.error.dismiss",
                        action: viewModel.dismissActionError
                    )
                    .accessibilityIdentifier("noShowHistory.saveError")
                }
                NoShowCountCard(
                    clientName: name, status: status, policy: viewModel.policy, identifier: "noShowHistory.count"
                ) { changeRule }
                if viewModel.didReset {
                    InlineNotice(style: .info, title: "noShowHistory.reset.done")
                        .accessibilityIdentifier("noShowHistory.resetDone")
                }
                history
                if viewModel.offersReset { resetCard(name: name) }
                FooterNote(text: "noShowHistory.footer", icon: .lock)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .refreshable { await viewModel.loadAsync() }
        .accessibilityIdentifier("noShowHistory.overview")
    }

    private func heading(_ client: Client) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(verbatim: client.name)
                .font(Typography.title).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("noShowHistory.clientName")
            Text(LocalizedStringResource(
                "noShowHistory.period", defaultValue: "Counted over the last \(viewModel.policy.countingMonths) months"
            ).localized(in: locale))
                .font(Typography.meta).foregroundStyle(Palette.ink2)
        }
    }

    // MARK: - History

    @ViewBuilder
    private var history: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("noShowHistory.history").font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if viewModel.entries.isEmpty {
                EmptyState(
                    icon: .calendar, title: Text("noShowHistory.empty.title"),
                    message: Text("noShowHistory.empty.message")
                )
                .accessibilityIdentifier("noShowHistory.empty")
            } else {
                ListCard(dividerInset: Spacing.md) {
                    ForEach(viewModel.entries) { entry in row(entry) }
                }
            }
        }
    }

    private func row(_ entry: NoShowHistoryEntry) -> some View {
        let formatters = viewModel.business.formatters(displayLocale: locale)
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.row) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(verbatim: formatters.shortDate(entry.startsAt))
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text(verbatim: entry.serviceName).font(Typography.meta).foregroundStyle(Palette.ink2)
                    Text(entry.kind == .noShow ? "noShowHistory.kind.noShow" : "noShowHistory.kind.lateCancel")
                        .font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: Spacing.sm)
                standing(entry.standing)
            }
            if entry.canForgive {
                Button { viewModel.forgive(entry) } label: {
                    Text("noShowHistory.forgive")
                        .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                        .frame(minHeight: Spacing.touchTarget, alignment: .leading)
                }
                .disabled(viewModel.isWorking)
                .accessibilityIdentifier("noShowHistory.forgive.\(entry.id.uuidString)")
            }
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("noShowHistory.row.\(entry.id.uuidString)")
    }

    private func standing(_ standing: NoShowHistoryEntry.Standing) -> some View {
        switch standing {
        case .counts: StatusChip(label: "noShowHistory.standing.counts", style: StatusPalette.attention)
        case .forgiven: StatusChip(label: "noShowHistory.standing.forgiven", style: StatusPalette.confirmed)
        case .expired: StatusChip(label: "noShowHistory.standing.expired", style: StatusPalette.completed)
        case .notCounted: StatusChip(label: "noShowHistory.standing.notCounted", style: StatusPalette.completed)
        }
    }

    private func resetCard(name: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("noShowHistory.reset.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            Text("noShowHistory.reset.detail").font(Typography.meta).foregroundStyle(Palette.ink2)
            Button { confirmsReset = true } label: { Text("noShowHistory.reset.button") }
                .buttonStyle(.belloSecondary)
                .disabled(viewModel.isWorking)
                .accessibilityIdentifier("noShowHistory.resetButton")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard(cornerRadius: Radius.tile)
    }

    @ViewBuilder
    private var changeRule: some View {
        NoShowPolicyView(
            editor: BookingSetupEditor(service: setup), localization: viewModel.business.localization,
            professionalName: viewModel.business.professionalFirstName
        )
    }
}
