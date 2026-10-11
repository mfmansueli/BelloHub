//
//  ExportRecordContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 4.10: what goes into the PDF, a copy for the client or for a health professional, then the file ready to
/// share. The PDF is built on this iPhone, lives in a protected temporary folder and is deleted after sharing or when
/// she leaves.
struct ExportRecordContentView: View {
    @State private var viewModel: ExportRecordViewModel
    @State private var isSharing = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(clientID: UUID, vault: VaultService, profile: ProfileService, exporter: any RecordExporting, locale: Locale) {
        _viewModel = State(initialValue: ExportRecordViewModel(
            clientID: clientID, vault: vault, profile: profile, exporter: exporter, locale: locale,
            resolve: { $0.resolved(in: locale) }
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bg)
                .navigationTitle(Text("exportRecord.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("common.close") }
                            .accessibilityIdentifier("exportRecord.closeButton")
                    }
                }
        }
        .task { await viewModel.loadAsync() }
        .onDisappear { viewModel.discardFile() }
        .sheet(isPresented: $isSharing) {
            if case .ready(let file) = viewModel.phase {
                ActivityShareSheet(url: file.url) { completed in
                    isSharing = false
                    viewModel.shareFinished(completed: completed)
                }
                .presentationDetents([.medium, .large])
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
        .interactiveDismissDisabled(viewModel.isWorking)
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .form: form
        case .ready(let file): ready(file)
        case .shared: shared
        case .loading: state(isMissing: false, message: nil)
        case .missing: state(isMissing: true, message: nil)
        case .failed(let message): state(isMissing: false, message: message)
        }
    }

    private func state(isMissing: Bool, message: String?) -> some View {
        RecordStateView(prefix: "exportRecord", isMissing: isMissing, errorMessage: message, retry: viewModel.load)
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("exportRecord.intro").font(Typography.meta).foregroundStyle(Palette.ink2)
                if let message = viewModel.exportErrorMessage {
                    ErrorNotice(
                        message: message, actionTitle: "recordHistory.error.dismiss",
                        action: viewModel.dismissExportError
                    )
                    .accessibilityIdentifier("exportRecord.error")
                }
                audience
                clientCard
                includes
                ChoiceChips(
                    title: "exportRecord.period", options: ExportPeriod.allCases,
                    isSelected: { viewModel.options.period == $0 }, label: { $0.title.resolved(in: locale) },
                    identifier: { "exportRecord.period.\($0.rawValue)" }, onSelect: { viewModel.options.period = $0 }
                )
                FooterNote(text: "exportRecord.footer", icon: .lock)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .accessibilityIdentifier("exportRecord.form")
        .safeAreaInset(edge: .bottom) { exportBar }
    }

    private var audience: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Picker(selection: Binding(get: { viewModel.options.audience }, set: viewModel.setAudience)) {
                ForEach(ExportAudience.allCases) { Text($0.title.resolved(in: locale)).tag($0) }
            } label: {
                Text("exportRecord.audience")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("exportRecord.audience")
            Text(viewModel.options.audience == .client
                ? "exportRecord.audience.clientHint" : "exportRecord.audience.doctorHint")
                .font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    private var clientCard: some View {
        let formatters = viewModel.business.formatters(displayLocale: locale)
        let name = viewModel.client?.name ?? ""
        return HStack(spacing: Spacing.md) {
            Avatar(name: name, id: viewModel.clientID.uuidString, size: 48).fixedAvatarText()
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(verbatim: name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(LocalizedStringResource(
                    "exportRecord.summary.treatments", defaultValue: "Treatments: \(viewModel.summary.treatmentCount)"
                ).localized(in: locale)).font(Typography.meta).foregroundStyle(Palette.ink2)
                Text(consentLine(formatters)).font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .belloCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("exportRecord.client")
    }

    private func consentLine(_ formatters: Formatters) -> LocalizedStringResource {
        guard let signed = viewModel.summary.consentSignedAt else {
            return LocalizedStringResource("exportRecord.summary.noConsent").localized(in: locale)
        }
        let date = formatters.shortDate(signed)
        return LocalizedStringResource("exportRecord.summary.consent", defaultValue: "ConsentRecord signed \(date)")
            .localized(in: locale)
    }

    private var includes: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("exportRecord.include").font(Typography.section).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ListCard(dividerInset: Spacing.md) {
                toggle(
                    "exportRecord.health", "exportRecord.health.detail", id: "health",
                    $viewModel.options.includeHealth
                )
                toggle(
                    "exportRecord.consent", "exportRecord.consent.detail", id: "consent",
                    $viewModel.options.includeConsent
                )
                toggle(
                    "exportRecord.treatments", "exportRecord.treatments.detail", id: "treatments",
                    $viewModel.options.includeTreatments
                )
                toggle(
                    "exportRecord.photos", "exportRecord.photos.detail", id: "photos",
                    $viewModel.options.includePhotos
                )
                notesToggle
            }
        }
    }

    private func toggle(_ title: StaticString, _ detail: StaticString, id: String, _ isOn: Binding<Bool>) -> some View {
        ToggleRow(title: text(title), subtitle: text(detail), isOn: isOn, identifier: "exportRecord.\(id)Toggle")
    }

    /// Off and disabled in the client's copy: the rule is `ExportOptions.allowsInternalNotes`.
    private var notesToggle: some View {
        let allowed = viewModel.options.allowsInternalNotes
        return ToggleRow(
            title: text("exportRecord.notes"),
            subtitle: allowed ? text("exportRecord.notes.detail") : text("exportRecord.notes.clientCopy"),
            isOn: Binding(
                get: { viewModel.options.effectiveIncludesInternalNotes },
                set: { viewModel.options.includeInternalNotes = $0 }
            ),
            identifier: "exportRecord.notesToggle"
        )
        .disabled(!allowed)
    }

    private var exportBar: some View {
        FlowBottomBar {
            Button { viewModel.export() } label: {
                if viewModel.isWorking {
                    ProgressView()
                } else {
                    Label { Text("exportRecord.export") } icon: { Image(icon: .download) }
                }
            }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canExport)
            .accessibilityIdentifier("exportRecord.exportButton")
        }
    }

    // MARK: - Ready and shared

    private func ready(_ file: ExportedFile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SuccessSeal().padding(.top, Spacing.xl)
                Text("exportRecord.ready.title").font(Typography.title).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("exportRecord.ready.message").font(Typography.meta).foregroundStyle(Palette.ink2)
                HStack(spacing: Spacing.row) {
                    Image(icon: .document).font(.system(size: 20)).foregroundStyle(Palette.roseDeepText)
                        .accessibilityHidden(true)
                    Text(verbatim: file.fileName).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .belloCard(cornerRadius: Radius.tile)
                // A bare file name is not a spoken label; the card says what it is and reads the name as its value.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("exportRecord.fileName.label"))
                .accessibilityValue(Text(verbatim: file.fileName))
                .accessibilityIdentifier("exportRecord.fileName")
                Button { isSharing = true } label: {
                    Label { Text("exportRecord.share") } icon: { Image(icon: .share) }
                }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("exportRecord.shareButton")
                Button { dismiss() } label: { Text("exportRecord.back") }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("exportRecord.backButton")
                FooterNote(text: "exportRecord.ready.deleted", icon: .info)
            }
            .padding(.horizontal, Spacing.gutter)
        }
        .accessibilityIdentifier("exportRecord.ready")
    }

    private var shared: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SuccessSeal().padding(.top, Spacing.xl)
                Text("exportRecord.shared.title").font(Typography.title).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("exportRecord.shared.message").font(Typography.meta).foregroundStyle(Palette.ink2)
                Button { dismiss() } label: { Text("exportRecord.back") }
                    .buttonStyle(.belloPrimary)
                    .accessibilityIdentifier("exportRecord.doneButton")
            }
            .padding(.horizontal, Spacing.gutter)
        }
        .accessibilityIdentifier("exportRecord.shared")
    }

    // MARK: - Helpers

    private func text(_ key: StaticString) -> String {
        LocalizedStringResource(key, defaultValue: String.LocalizationValue(key.description)).resolved(in: locale)
    }
}
