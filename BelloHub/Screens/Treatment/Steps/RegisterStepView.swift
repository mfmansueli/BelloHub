//
//  RegisterStepView.swift
//  BelloHub
//

import SwiftUI

/// 5.1 Tx-1-Register: how does she want to record this visit? By voice when dictation is available, by hand always.
/// When voice is not available the screen says so calmly and makes the form the main action: it is a complete way to
/// record, not a lesser one, and never an error.
struct RegisterStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel
    let onCancel: () -> Void

    @Environment(\.locale) private var locale
    @State private var settings = SystemSettingsOpener()

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("treatmentFlow.register.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) { Text("common.cancel") }
                        .accessibilityIdentifier("treatmentFlow.register.cancelButton")
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loading: loading
        case .failed: failed
        case .clientMissing: missing
        case .ready: ready
        }
    }

    // MARK: - Ready

    private var ready: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                visitCard
                if viewModel.heardNothing {
                    InlineNotice(
                        style: .info, title: "treatmentFlow.register.heardNothing.title",
                        message: "treatmentFlow.register.heardNothing.message"
                    )
                    .accessibilityIdentifier("treatmentFlow.register.heardNothing")
                }
                switch viewModel.registerOffer {
                case .voiceAndManual: voiceOffer
                case .manualOnly(let reason): manualOffer(reason)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .accessibilityIdentifier("treatmentFlow.register")
    }

    private var visitCard: some View {
        TreatmentVisitCard(
            name: viewModel.client?.name ?? "", id: viewModel.clientID, subtitle: viewModel.visitSubtitle
        )
    }

    private var voiceOffer: some View {
        VStack(spacing: Spacing.lg) {
            Button { viewModel.startListening() } label: {
                Image(icon: .mic)
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 128, height: 128)
                    .background(Palette.rose, in: Circle())
                    .padding(Spacing.lg)
                    .background(Palette.roseWash, in: Circle())
            }
            .accessibilityLabel(Text("treatmentFlow.register.voiceButton"))
            .accessibilityIdentifier("treatmentFlow.register.voiceButton")
            VStack(spacing: Spacing.sm) {
                Text("treatmentFlow.register.heading").font(Typography.title).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("treatmentFlow.register.voiceIntro").font(Typography.body).foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
            }
            exampleCard
            Button { viewModel.writeItMyself() } label: { Text("treatmentFlow.register.manual") }
                .buttonStyle(.belloTertiary)
                .accessibilityIdentifier("treatmentFlow.register.manualButton")
        }
    }

    private var exampleCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("treatmentFlow.register.example.title").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            Text("treatmentFlow.register.example.text").font(Typography.subtitle).foregroundStyle(Palette.ink)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func manualOffer(_ reason: VoiceFlowRules.ManualReason) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(icon: .pencil)
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Palette.roseDeepText)
                .frame(width: 96, height: 96)
                .background(Palette.roseDeepWash, in: Circle())
                .accessibilityHidden(true)
            VStack(spacing: Spacing.sm) {
                Text("treatmentFlow.register.manualHeading").font(Typography.title).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(reasonText(reason)).font(Typography.body).foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("treatmentFlow.register.reason")
            }
            Button { viewModel.writeItMyself() } label: { Text("treatmentFlow.register.start") }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("treatmentFlow.register.manualButton")
            if reason == .permissionDenied {
                Button { settings.openSettings() } label: { Text("import.openSettings") }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("treatmentFlow.register.settingsButton")
            }
            FooterNote(text: "treatmentFlow.register.manualNote", icon: .lock)
        }
    }

    private func reasonText(_ reason: VoiceFlowRules.ManualReason) -> LocalizedStringKey {
        switch reason {
        case .notAvailableYet: "treatmentFlow.register.reason.notAvailable"
        case .permissionDenied: "treatmentFlow.register.reason.denied"
        case .languageUnsupported: "treatmentFlow.register.reason.language"
        }
    }

    // MARK: - Other states

    private var loading: some View {
        VStack(spacing: Spacing.md) {
            Skeleton(height: 80)
            Skeleton(height: 128)
            Skeleton(height: 120)
            Spacer(minLength: 0)
        }
        .padding(Spacing.gutter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("treatmentFlow.loading"))
        .accessibilityIdentifier("treatmentFlow.loading")
    }

    private var failed: some View {
        VStack(spacing: Spacing.md) {
            ErrorNotice(
                message: LocalizedStringResource(
                    "treatmentFlow.error.load", defaultValue: "We could not open this record. Try again."
                )
                    .resolved(in: locale), actionTitle: "treatmentFlow.retry",
                action: viewModel.reload
            )
            Spacer(minLength: 0)
        }
        .padding(Spacing.gutter)
        .accessibilityIdentifier("treatmentFlow.error")
    }

    private var missing: some View {
        EmptyState(
            icon: .user, title: "treatmentFlow.missing.title", message: "treatmentFlow.missing.message",
            actionTitle: "treatmentFlow.missing.close", action: onCancel
        )
        .accessibilityIdentifier("treatmentFlow.missing")
    }
}
