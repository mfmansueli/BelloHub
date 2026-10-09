//
//  RecoveryKeyContentView.swift
//  BelloHub
//

import SwiftUI

/// The 12 words, masked until "Show with Face ID"; Save to Files and Print once revealed; the "I saved it somewhere
/// safe" confirmation that records the date. The words are marked privacy-sensitive, so the system hides them in the
/// app switcher, and they never go to the pasteboard.
struct RecoveryKeyContentView: View {
    @State private var viewModel: RecoveryKeyViewModel
    @State private var fileURL: URL?

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize

    init(service: RecoveryKeyService, businessName: String) {
        _viewModel = State(initialValue: RecoveryKeyViewModel(service: service, businessName: businessName))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("recoveryKey.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                if viewModel.done { doneNotice }
                notices
                wordsCard
                if viewModel.isRevealed { exportRows }
                whyItMatters
                confirmation
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("recoveryKey.title"))
        .navigationBarTitleDisplayMode(.large)
        .onDisappear(perform: viewModel.clear)
    }

    // MARK: - Sections

    private var doneNotice: some View {
        InlineNotice(style: .info, title: "recoveryKey.done.title", message: "recoveryKey.done.message")
            .accessibilityIdentifier("recoveryKey.doneNotice")
    }

    @ViewBuilder
    private var notices: some View {
        if let notice = viewModel.revealNotice {
            InlineNotice(
                style: .warning,
                title: notice == .noKey ? "recoveryKey.error.noKey.title" : "recoveryKey.error.notRecognized.title",
                message: notice == .noKey
                    ? "recoveryKey.error.noKey.message" : "recoveryKey.error.notRecognized.message"
            )
            .accessibilityIdentifier("recoveryKey.revealError")
        }
    }

    private var wordsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("recoveryKey.words.title").font(Typography.section).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Spacing.sm)
                if !viewModel.isRevealed {
                    Button(action: viewModel.reveal) { Text(revealTitle) }
                        .buttonStyle(.belloTertiary)
                        .disabled(viewModel.isRevealing)
                        .accessibilityIdentifier("recoveryKey.revealButton")
                }
            }
            wordsGrid
            Text(viewModel.isRevealed ? "recoveryKey.words.revealedNote" : "recoveryKey.words.maskedNote")
                .font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
        .padding(Spacing.md)
        .belloCard()
    }

    /// Three columns at the default size, one at accessibility sizes so a word never wraps mid-way.
    private var wordsGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: Spacing.sm), count: typeSize.isAccessibilitySize ? 1 : 3
        )
        return LazyVGrid(columns: columns, spacing: Spacing.sm) {
            ForEach(viewModel.cells) { cell in
                HStack(spacing: Spacing.sm) {
                    Text(verbatim: "\(cell.position)").font(Typography.meta).foregroundStyle(Palette.ink2)
                    Text(verbatim: cell.text).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.row)
                .frame(minHeight: Spacing.touchTarget)
                .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("recoveryKey.word.\(cell.position)")
            }
        }
        .privacySensitive()
        .environment(\.layoutDirection, .leftToRight)
    }

    private var exportRows: some View {
        ListCard(dividerInset: 72) {
            ShareLink(item: fileURL ?? URL(fileURLWithPath: "/dev/null")) {
                MoreRow(icon: .download, tint: .sage, title: Text("recoveryKey.saveToFiles"),
                        subtitle: Text("recoveryKey.saveToFiles.subtitle"))
            }
            .buttonStyle(.plain)
            .disabled(fileURL == nil)
            .accessibilityIdentifier("recoveryKey.saveToFilesButton")
            Button { viewModel.printKey(locale: locale) } label: {
                MoreRow(icon: .print, tint: .peach, title: Text("recoveryKey.print"),
                        subtitle: Text("recoveryKey.print.subtitle"))
            }
            .accessibilityIdentifier("recoveryKey.printButton")
        }
        .onAppear { fileURL = viewModel.prepareFile(locale: locale) }
    }

    private var whyItMatters: some View {
        SettingsSection(title: "recoveryKey.why.title") {
            Text("recoveryKey.why.message").font(Typography.body).foregroundStyle(Palette.ink2)
        }
    }

    private var confirmation: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            ListCard(dividerInset: Spacing.md) {
                ToggleRow(
                    title: String(localized: "recoveryKey.confirm.title"),
                    subtitle: String(localized: "recoveryKey.confirm.subtitle"),
                    isOn: $viewModel.confirmsSafe, identifier: "recoveryKey.confirmSwitch"
                )
                .disabled(!viewModel.isRevealed)
            }
            Button(action: viewModel.confirmSaved) { Text("recoveryKey.confirm.action") }
                .buttonStyle(.belloPrimary)
                .disabled(!viewModel.canConfirm || viewModel.done)
                .accessibilityIdentifier("recoveryKey.confirmButton")
        }
    }

    private var revealTitle: LocalizedStringKey {
        switch viewModel.biometryKind {
        case .faceID: "recoveryKey.reveal.faceID"
        case .touchID: "recoveryKey.reveal.touchID"
        case .opticID: "recoveryKey.reveal.opticID"
        case .passcodeOnly: "recoveryKey.reveal.passcode"
        }
    }
}
