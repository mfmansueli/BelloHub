//
//  NoShowMarkContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 3.7: did she miss it, does it count (D13), what that does to her count, and an optional friendly note
/// that opens in the chat after saving. The visit is only changed when she confirms.
struct NoShowMarkContentView: View {
    @State private var viewModel: NoShowMarkViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(BookingSetupService.self) private var setup

    init(
        appointmentID: UUID, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        setup: BookingSetupService, messages: MessageService
    ) {
        _viewModel = State(initialValue: NoShowMarkViewModel(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile, setup: setup,
            messages: messages
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bg)
                .navigationTitle(Text("noShowMark.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("common.close") }
                            .accessibilityIdentifier("noShowMark.closeButton")
                    }
                }
        }
        .task { await viewModel.loadAsync() }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if let done = viewModel.done {
            finished(done)
        } else if let visit = viewModel.visit {
            form(visit)
        } else {
            VisitStateView(
                prefix: "noShowMark", isMissing: viewModel.isMissing, errorMessage: viewModel.errorMessage,
                retry: viewModel.load
            )
        }
    }

    // MARK: - Form

    private func form(_ visit: VisitContext) -> some View {
        let name = firstName(visit.client)
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VisitSummaryRow(
                    visit: visit, formatters: viewModel.business.formatters(displayLocale: locale), now: Date(),
                    identifier: "noShowMark.summary"
                )
                if viewModel.canMark {
                    question(name: name)
                    if let message = viewModel.actionErrorMessage {
                        ErrorNotice(
                            message: message, actionTitle: "appointment.error.dismiss",
                            action: viewModel.dismissActionError
                        )
                        .accessibilityIdentifier("noShowMark.saveError")
                    }
                    kind(name: name)
                    if let status = viewModel.shownStatus {
                        NoShowCountCard(
                            clientName: name, status: status, policy: viewModel.policy, identifier: "noShowMark.count"
                        ) { changeRule }
                    }
                    note(name: name)
                } else {
                    InlineNotice(style: .info, title: "noShowMark.unavailable")
                        .accessibilityIdentifier("noShowMark.unavailable")
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .accessibilityIdentifier("noShowMark.form")
        .safeAreaInset(edge: .bottom) { if viewModel.canMark { buttons } }
    }

    private func question(name: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(LocalizedStringResource("noShowMark.question", defaultValue: "Did \(name) miss this one?")
                .localized(in: locale))
                .font(Typography.title).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("noShowMark.questionDetail").font(Typography.body).foregroundStyle(Palette.ink2)
        }
    }

    private func kind(name: String) -> some View {
        VStack(spacing: Spacing.sm) {
            ChoiceCard(
                title: String(localized: "noShowMark.kind.counts", locale: locale),
                subtitle: String(localized: "noShowMark.kind.counts.detail", locale: locale),
                isSelected: viewModel.countsAgainstClient, identifier: "noShowMark.kind.counts"
            ) { viewModel.countsAgainstClient = true }
            ChoiceCard(
                title: String(localized: "noShowMark.kind.excused", locale: locale),
                subtitle: String(localized: "noShowMark.kind.excused.detail", locale: locale),
                isSelected: !viewModel.countsAgainstClient, identifier: "noShowMark.kind.excused"
            ) { viewModel.countsAgainstClient = false }
        }
    }

    private func note(name: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Toggle(isOn: $viewModel.sendsNote) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("noShowMark.note.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text("noShowMark.note.detail").font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
            .tint(Palette.sage)
            .frame(minHeight: Spacing.touchTarget)
            .accessibilityIdentifier("noShowMark.noteToggle")
            if viewModel.sendsNote, let preview = viewModel.notePreview {
                Text(verbatim: preview)
                    .font(Typography.meta).foregroundStyle(Palette.sageText)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                    .accessibilityIdentifier("noShowMark.notePreview")
            }
        }
        .padding(Spacing.md)
        .belloCard(cornerRadius: Radius.tile)
    }

    @ViewBuilder
    private var changeRule: some View {
        NoShowPolicyView(
            editor: BookingSetupEditor(service: setup), localization: viewModel.business.localization,
            professionalName: viewModel.business.professionalFirstName
        )
    }

    private var buttons: some View {
        VStack(spacing: Spacing.sm) {
            Button { viewModel.confirm() } label: {
                if viewModel.isWorking { ProgressView() } else { Text("noShowMark.confirm") }
            }
            .buttonStyle(.belloPrimary)
            .disabled(viewModel.isWorking)
            .accessibilityIdentifier("noShowMark.confirmButton")
            Button { dismiss() } label: { Text("noShowMark.notNow") }
                .buttonStyle(.belloTertiary)
                .accessibilityIdentifier("noShowMark.notNowButton")
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
    }

    // MARK: - Done

    private func finished(_ done: NoShowMarkViewModel.Done) -> some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                SuccessSeal().padding(.top, Spacing.xl)
                Text(done.forgiven ? "noShowMark.done.excused" : "noShowMark.done.counted")
                    .font(Typography.title).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("noShowMark.done.title")
                if let message = done.message { messageOutcome(message) }
                Button { dismiss() } label: { Text("appointment.done") }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("noShowMark.doneButton")
            }
            .padding(.horizontal, Spacing.gutter)
        }
        .accessibilityIdentifier("noShowMark.done")
    }

    @ViewBuilder
    private func messageOutcome(_ outcome: MessageService.Outcome) -> some View {
        switch outcome {
        case .opened(let channel):
            Text(channel == .whatsapp ? "appointment.opened.whatsapp" : "appointment.opened.sms")
                .font(Typography.meta).foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("noShowMark.opened")
        case .needsShareSheet(let text):
            ShareFallbackCard(text: text, identifier: "noShowMark.shareFallback")
        }
    }

    private func firstName(_ client: Client) -> String {
        client.name.split(separator: " ").first.map(String.init) ?? client.name
    }
}
