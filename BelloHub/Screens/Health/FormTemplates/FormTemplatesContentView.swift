//
//  FormTemplatesContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 6.14: the health questions as switches, the consent texts she can read, and how often she asks again.
/// One primary action, Save changes, sits at the bottom.
struct FormTemplatesContentView: View {
    @State private var viewModel: FormTemplatesViewModel
    @Environment(\.locale) private var locale

    init(repository: (any HealthRepository)?, profile: ProfileService, locale: Locale) {
        _viewModel = State(initialValue: FormTemplatesViewModel(
            repository: repository, profile: profile, locale: locale
        ))
    }

    var body: some View {
        @Bindable var model = viewModel
        VStack(spacing: 0) {
            ScrollView {
                StaggeredStack(spacing: Spacing.md) {
                    Text("formTemplates.subtitle")
                        .font(Typography.body)
                        .foregroundStyle(Palette.ink2)
                        .accessibilityIdentifier("formTemplates.subtitle")
                    content
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xl)
            }
            // A sibling of the scroll view, so the scroll view ends where the bar begins.
            if viewModel.hasLoaded { saveBar }
        }
        .background(Palette.bg)
        .navigationTitle(Text("formTemplates.title"))
        .task { await viewModel.load() }
        .sheet(item: $model.previewSheet) { sheet in
            ConsentPreviewSheet(viewModel: sheet)
        }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if viewModel.errorMessage != nil { errorState } else { loadingState }
        } else {
            questionsSection
            consentSection
            reviewSection
            versionNote
        }
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.sm) {
            Skeleton(height: 52)
            Skeleton(height: 52)
            Skeleton(height: 52)
        }
        .padding(.top, Spacing.section)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("formTemplates.title"))
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("formTemplates.loading")
    }

    private var errorState: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            InlineNotice(style: .warning, title: "formTemplates.error.load")
            Button { viewModel.reload() } label: { Text("health.retry") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("formTemplates.retryButton")
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Sections

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "formTemplates.section.questions")
            ListCard(dividerInset: Spacing.md) {
                ForEach(viewModel.offered) { question in
                    ToggleRow(
                        title: question.name,
                        isOn: Binding(
                            get: { viewModel.isOn(question) }, set: { viewModel.setOn($0, for: question) }
                        ),
                        identifier: "formTemplates.question.\(question.key)"
                    )
                }
            }
            if viewModel.hasNoQuestionsOn {
                Text("formTemplates.needOne")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.coralText)
                    .accessibilityIdentifier("formTemplates.needOne")
            }
        }
    }

    /// The consent texts, one row each: the treatment consent, the guardian's (minors) and the photo consent.
    private var consentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "health.section.consent")
            ListCard(dividerInset: Spacing.md) {
                ForEach(LegalDocument.allCases, id: \.self) { document in
                    consentRow(document)
                }
            }
            Text("formTemplates.consent.hint").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    private func consentRow(_ document: LegalDocument) -> some View {
        Button { viewModel.previewConsent(document) } label: {
            HStack(spacing: Spacing.row) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(ConsentPresentation.title(of: document))
                        .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    if let version = viewModel.consentVersions[document] {
                        Text(verbatim: ConsentPresentation.versionLine(version, locale: locale))
                            .font(Typography.footnote).foregroundStyle(Palette.ink2)
                    }
                }
                Spacer(minLength: Spacing.sm)
                Image(icon: .forward)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("formTemplates.consent.\(document.rawValue)")
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title: "formTemplates.section.ask")
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
                ForEach(HealthFormTemplateRules.reviewOptions, id: \.self) { months in
                    Button { viewModel.reviewMonths = months } label: {
                        Text(LocalizedStringResource(
                            "formTemplates.months", defaultValue: "\(months) months"
                        ).localized(in: locale))
                    }
                    .buttonStyle(.belloChip(selected: viewModel.reviewMonths == months))
                    .accessibilityAddTraits(viewModel.reviewMonths == months ? .isSelected : [])
                    .accessibilityIdentifier("formTemplates.months.\(months)")
                }
            }
        }
    }

    private var versionNote: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("formTemplates.versionNote").font(Typography.footnote).foregroundStyle(Palette.ink2)
            if let version = viewModel.currentVersion {
                Text(LocalizedStringResource(
                    "formTemplates.version", defaultValue: "Current version: \(version)"
                ).localized(in: locale))
                    .font(Typography.footnoteStrong)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("formTemplates.version")
            }
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Save

    /// "Save changes", which reads "Saved" from a successful save until she changes something again.
    private var saveTitle: LocalizedStringKey {
        viewModel.didSave ? "formTemplates.saved" : "formTemplates.save"
    }

    private var saveBar: some View {
        VStack(spacing: Spacing.sm) {
            if let message = viewModel.errorMessage {
                Text(verbatim: message)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.coralText)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityIdentifier("formTemplates.error")
            }
            Button { viewModel.save() } label: {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Text(saveTitle)
                }
            }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canSave)
            .accessibilityIdentifier("formTemplates.saveButton")
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
    }
}
