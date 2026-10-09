//
//  AISettingsContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 7.5. See `AISettingsView`.
struct AISettingsContentView: View {
    @State private var viewModel: AISettingsViewModel
    private let profile: ProfileService
    @Environment(\.locale) private var locale

    init(profile: ProfileService, voice: any VoiceCapturing, locale: Locale) {
        self.profile = profile
        _viewModel = State(initialValue: AISettingsViewModel(
            store: UserDefaultsAIPreferencesStore(), voice: voice, locale: locale
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("aiSettings.subtitle").font(Typography.meta).foregroundStyle(Palette.ink2)
                whereItRuns
                howItWorks
                settings
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .background(Palette.bg)
        .navigationTitle(Text("aiSettings.title"))
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.loadAsync() }
        .accessibilityIdentifier("aiSettings.screen")
    }

    // MARK: - Where it runs

    private var whereItRuns: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("aiSettings.where")
            ListCard(dividerInset: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("aiSettings.device.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                        Spacer(minLength: Spacing.sm)
                        status
                    }
                    Text("aiSettings.device.detail").font(Typography.meta).foregroundStyle(Palette.ink2)
                }
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("aiSettings.device")
                cloudRow
            }
            FooterNote(text: "aiSettings.where.footer", icon: .info)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch viewModel.availability {
        case .available: StatusChip(label: "aiSettings.status.ready", style: StatusPalette.confirmed)
        case .permissionDenied: StatusChip(label: "aiSettings.status.denied", style: StatusPalette.pending)
        case .languageUnsupported: StatusChip(label: "aiSettings.status.language", style: StatusPalette.pending)
        case .notAvailableYet: StatusChip(label: "aiSettings.status.notYet", style: StatusPalette.completed)
        case nil: ProgressView().accessibilityLabel(Text("aiSettings.status.checking"))
        }
    }

    /// Shown, off and unavailable on purpose (D23): the row tells her what it would be, and that it is not there yet.
    private var cloudRow: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Toggle(isOn: .constant(false)) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("aiSettings.cloud.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    Text("aiSettings.cloud.detail").font(Typography.meta).foregroundStyle(Palette.ink2)
                }
            }
            .tint(Palette.sage)
            .disabled(true)
            Text("aiSettings.cloud.notYet").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aiSettings.cloud")
    }

    // MARK: - How it works

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("aiSettings.how")
            VStack(alignment: .leading, spacing: Spacing.row) {
                Text("aiSettings.does.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                bullet("aiSettings.does.1", icon: .check, color: Palette.sageText)
                bullet("aiSettings.does.2", icon: .check, color: Palette.sageText)
                bullet("aiSettings.does.3", icon: .check, color: Palette.sageText)
                Text("aiSettings.never.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    .padding(.top, Spacing.sm)
                bullet("aiSettings.never.1", icon: .close, color: Palette.coralText)
                bullet("aiSettings.never.2", icon: .close, color: Palette.coralText)
                bullet("aiSettings.never.3", icon: .close, color: Palette.coralText)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .belloCard()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("aiSettings.howCard")
        }
    }

    private func bullet(_ key: LocalizedStringKey, icon: Icon, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.row) {
            Image(icon: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(color).accessibilityHidden(true)
            Text(key).font(Typography.meta).foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("aiSettings.settings")
            ListCard(dividerInset: Spacing.md) {
                ToggleRow(
                    title: text("aiSettings.voice.title"), subtitle: text("aiSettings.voice.detail"),
                    isOn: $viewModel.voiceEnabled, identifier: "aiSettings.voiceToggle"
                )
                ToggleRow(
                    title: text("aiSettings.ai.title"), subtitle: text("aiSettings.ai.detail"),
                    isOn: $viewModel.aiEnabled, identifier: "aiSettings.aiToggle"
                )
                reviewRow
                ToggleRow(
                    title: text("aiSettings.delete.title"), subtitle: text("aiSettings.delete.detail"),
                    isOn: $viewModel.deleteRecordings, identifier: "aiSettings.deleteToggle"
                )
                languageRow
                NavigationLink {
                    RecordTemplateView(profile: profile)
                } label: {
                    linkLabel(title: "aiSettings.fields.title", detail: "aiSettings.fields.detail")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("aiSettings.fieldsRow")
            }
        }
    }

    /// On and disabled: D23 makes the check before saving a rule, not a preference.
    private var reviewRow: some View {
        Toggle(isOn: .constant(viewModel.preferences.reviewRequired)) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("aiSettings.review.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text("aiSettings.review.detail").font(Typography.meta).foregroundStyle(Palette.ink2)
                Text("aiSettings.review.locked").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
            }
        }
        .tint(Palette.sage)
        .disabled(true)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 52)
        .accessibilityIdentifier("aiSettings.reviewToggle")
    }

    private var languageRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("aiSettings.language.title").font(Typography.body).foregroundStyle(Palette.ink)
                Text("aiSettings.language.detail").font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: Spacing.sm)
            Text(verbatim: locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
                .font(Typography.meta).foregroundStyle(Palette.ink2)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("aiSettings.languageRow")
    }

    private func linkLabel(title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(Typography.body).foregroundStyle(Palette.ink)
                Text(detail).font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: Spacing.sm)
            Image(icon: .forward).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: Spacing.touchTarget)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).font(Typography.section).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
    }

    private func text(_ key: StaticString) -> String {
        LocalizedStringResource(key, defaultValue: String.LocalizationValue(key.description)).resolved(in: locale)
    }
}
