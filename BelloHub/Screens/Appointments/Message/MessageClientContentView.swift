//
//  MessageClientContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 3.6: her quick replies, the one she picked filled in for this visit, and the button that opens the chat.
/// She always reads the text before it opens (D14: the app never sends by itself).
struct MessageClientContentView: View {
    @State private var viewModel: MessageClientViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(
        appointmentID: UUID, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        setup: BookingSetupService, messages: MessageService
    ) {
        _viewModel = State(initialValue: MessageClientViewModel(
            appointmentID: appointmentID, appointments: appointments, vault: vault, profile: profile, setup: setup,
            messages: messages
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bg)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("common.close") }
                            .accessibilityIdentifier("messageClient.closeButton")
                    }
                }
        }
        .task { await viewModel.loadAsync() }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    private var title: Text {
        guard let client = viewModel.visit?.client else { return Text("messageClient.title.plain") }
        let name = client.name.split(separator: " ").first.map(String.init) ?? client.name
        return Text(LocalizedStringResource("messageClient.title", defaultValue: "Message \(name)")
            .localized(in: locale))
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if let visit = viewModel.visit {
            form(visit)
        } else {
            VisitStateView(
                prefix: "messageClient", isMissing: viewModel.isMissing, errorMessage: viewModel.errorMessage,
                retry: viewModel.load
            )
        }
    }

    // MARK: - Form

    private func form(_ visit: VisitContext) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VisitSummaryRow(
                    visit: visit, formatters: viewModel.business.formatters(displayLocale: locale), now: Date(),
                    identifier: "messageClient.summary"
                )
                Text(viewModel.hasNumber ? "messageClient.subtitle" : "messageClient.subtitle.noNumber")
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("messageClient.subtitle")
                replies
                preview
                outcome
                NavigationLink { QuickRepliesView() } label: {
                    Text("messageClient.editTemplates")
                        .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                        .frame(minHeight: Spacing.touchTarget, alignment: .leading)
                }
                .accessibilityIdentifier("messageClient.editTemplatesLink")
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .accessibilityIdentifier("messageClient.form")
        .safeAreaInset(edge: .bottom) { openButton }
    }

    private var replies: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("messageClient.replies")
                .font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            ForEach(viewModel.replies) { reply in
                ChoiceCard(
                    title: reply.title, isSelected: reply.id == viewModel.selectedID,
                    identifier: "messageClient.reply.\(reply.id.uuidString)"
                ) { viewModel.select(reply) }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let text = viewModel.text {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("messageClient.preview")
                    .font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: text)
                    .font(Typography.body).foregroundStyle(Palette.sageText)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                    .accessibilityIdentifier("messageClient.preview")
            }
        }
    }

    @ViewBuilder
    private var outcome: some View {
        switch viewModel.outcome {
        case .opened(let channel)?:
            Text(channel == .whatsapp ? "appointment.opened.whatsapp" : "appointment.opened.sms")
                .font(Typography.meta).foregroundStyle(Palette.sageText)
                .accessibilityIdentifier("messageClient.opened")
        case .needsShareSheet(let text)?:
            ShareFallbackCard(text: text, identifier: "messageClient.shareFallback")
        case nil:
            EmptyView()
        }
    }

    private var openButton: some View {
        Button { viewModel.open() } label: {
            if viewModel.isWorking {
                ProgressView()
            } else {
                Text(viewModel.hasNumber ? "messageClient.open" : "messageClient.share")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(viewModel.selectedReply == nil || viewModel.isWorking)
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
        .accessibilityIdentifier("messageClient.openButton")
    }
}
