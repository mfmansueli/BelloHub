//
//  ExportAllContentView.swift
//  BelloHub
//

import SwiftUI

/// Everything in her account as one ZIP (CSV of clients, appointments and records, a summary PDF, photos if she
/// wants), built on the iPhone and handed to the share sheet or Files (D18). The temp file is deleted when the
/// screen leaves.
struct ExportAllContentView: View {
    @State private var viewModel: ExportAllViewModel

    @Environment(\.locale) private var locale

    init(export: DataExportService, profile: ProfileService) {
        _viewModel = State(initialValue: ExportAllViewModel(export: export, profile: profile))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("export.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                if let message = viewModel.errorMessage {
                    ErrorNotice(message: message).accessibilityIdentifier("export.error")
                }
                include
                delivery
                if viewModel.fileURL == nil { prepareButton } else { ready }
                FooterNote(text: "export.footer", icon: .lock)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("export.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: viewModel.discard)
    }

    // MARK: - Sections

    private var include: some View {
        SettingsSection(title: "export.section.include") {
            ListCard(dividerInset: Spacing.md) {
                staticRow("export.include.clients", "export.include.clients.subtitle")
                staticRow("export.include.appointments", "export.include.appointments.subtitle")
                staticRow("export.include.records", "export.include.records.subtitle")
                ToggleRow(
                    title: String(interface: LocalizedStringResource("export.include.photos")),
                    subtitle: String(interface: LocalizedStringResource("export.include.photos.subtitle")),
                    isOn: $viewModel.contents.includesPhotos, identifier: "export.photosSwitch"
                )
                .disabled(viewModel.fileURL != nil)
            }
        }
    }

    private var delivery: some View {
        SettingsSection(title: "export.section.delivery", subtitle: "export.delivery.subtitle") {
            EmptyView()
        }
    }

    private var prepareButton: some View {
        Button { viewModel.prepare(locale: locale) } label: {
            if viewModel.isPreparing {
                HStack(spacing: Spacing.sm) {
                    ProgressView().tint(Palette.onAction)
                    Text("export.preparing")
                }
            } else {
                Text("export.prepare")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(viewModel.isPreparing)
        .accessibilityIdentifier("export.prepareButton")
    }

    @ViewBuilder
    private var ready: some View {
        if let url = viewModel.fileURL {
            VStack(alignment: .leading, spacing: Spacing.row) {
                InlineNotice(style: .info, title: "export.ready", message: "export.ready.message")
                    .accessibilityIdentifier("export.readyNotice")
                ShareLink(item: url) {
                    HStack(spacing: Spacing.sm) {
                        Image(icon: .share).accessibilityHidden(true)
                        Text("export.share")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("export.shareButton")
                Button(action: viewModel.discard) { Text("export.startOver") }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("export.startOverButton")
            }
        }
    }

    private func staticRow(_ title: LocalizedStringKey, _ subtitle: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.row) {
            Image(icon: .check).foregroundStyle(Palette.sageText).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text(subtitle).font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}
