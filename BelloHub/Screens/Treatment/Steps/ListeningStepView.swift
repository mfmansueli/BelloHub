//
//  ListeningStepView.swift
//  BelloHub
//

import SwiftUI

/// 5.2 Tx-2-Listening: while she speaks, the words appear as they are heard and the time counts up. There is no fake
/// waveform: the only moving part is a calm ring, which stops under Reduce Motion. Nothing is recorded to a file; only
/// the transcript, which she reviews, goes on.
struct ListeningStepView: View {
    @Bindable var viewModel: TreatmentFlowViewModel

    @Environment(\.locale) private var locale
    @Environment(\.motionPolicy) private var policy
    @State private var pulsing = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Text(verbatim: "\(BidiIsolate.wrap(viewModel.client?.name ?? "")) · \(BidiIsolate.wrap(viewModel.serviceName))")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("treatmentFlow.listening.subtitle")
                indicator
                Text("treatmentFlow.listening.title").font(Typography.title).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: elapsedText).font(Typography.numeral).foregroundStyle(Palette.ink2)
                    .accessibilityLabel(Text(verbatim: elapsedText))
                    .accessibilityIdentifier("treatmentFlow.listening.elapsed")
                if viewModel.listeningPhase == .askToWrapUp {
                    InlineNotice(style: .info, title: "treatmentFlow.listening.wrapUp")
                        .accessibilityIdentifier("treatmentFlow.listening.wrapUp")
                }
                transcriptCard
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .background(Palette.bg)
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { viewModel.cancelListening() } label: { Text("common.cancel") }
                    .accessibilityIdentifier("treatmentFlow.listening.cancelButton")
            }
        }
        .safeAreaInset(edge: .bottom) {
            FlowBottomBar {
                Button { viewModel.finishListeningTapped() } label: { Text("treatmentFlow.listening.finish") }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("treatmentFlow.listening.finishButton")
            }
        }
        .onAppear { startPulse() }
        .accessibilityIdentifier("treatmentFlow.listening")
    }

    // MARK: - Parts

    private var indicator: some View {
        Image(icon: .mic)
            .font(.system(size: 40, weight: .regular))
            .foregroundStyle(Palette.ink)
            .frame(width: 112, height: 112)
            .background(Palette.rose, in: Circle())
            .padding(Spacing.lg)
            .background(Palette.roseWash, in: Circle())
            .scaleEffect(pulsing ? 1.04 : 1)
            .accessibilityHidden(true)
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("treatmentFlow.listening.hears").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            if VoiceFlowRules.hasContent(viewModel.transcript) {
                Text(verbatim: viewModel.transcript).font(Typography.body).foregroundStyle(Palette.ink)
            } else {
                Text("treatmentFlow.listening.waiting").font(Typography.body).foregroundStyle(Palette.ink2)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("treatmentFlow.listening.transcript")
    }

    private var elapsedText: String {
        Duration.seconds(Int(viewModel.elapsed)).formatted(.time(pattern: .minuteSecond).locale(locale))
    }

    /// The ring breathes slowly, only when motion is allowed (Reduce Motion, Low Power Mode and UI tests keep it still).
    private func startPulse() {
        guard policy.allowsAmbient else { return }
        withAnimation(.easeInOut(duration: Motion.Duration.pulse).repeatForever(autoreverses: true)) { pulsing = true }
    }
}
