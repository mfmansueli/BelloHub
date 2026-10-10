//
//  FormTemplatesContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 6.14: the health questions as switches and how often she asks again. No consent texts (D55).
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
        .background(Palette.bg)
        .navigationTitle(Text("formTemplates.title"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if viewModel.hasLoaded { saveBar }
        }
        .task { await viewModel.load() }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasLoaded {
            if viewModel.errorMessage != nil { errorState } else { loadingState }
        } else {
            questionsSection
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
