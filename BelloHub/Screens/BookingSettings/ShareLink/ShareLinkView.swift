//
//  ShareLinkView.swift
//  BelloHub
//

import SwiftUI

/// 6.8 Share your link. Her address (typed or picked from suggestions, checked as she types), then the link with its
/// QR code, the system share sheet, a printable table card and the texts for an Instagram bio and WhatsApp chats.
/// Until she goes online (S8) a notice says the link does not work yet. Pushed from the booking page settings.
struct ShareLinkView: View {
    @State private var viewModel: ShareLinkViewModel
    @State private var cardImage: Image?
    let publishing: PublishingService

    @Environment(\.locale) private var locale

    init(
        editor: BookingSetupEditor, publishing: PublishingService, displayName: String, businessName: String,
        localization: AppLocalization
    ) {
        self.publishing = publishing
        _viewModel = State(initialValue: ShareLinkViewModel(
            editor: editor, displayName: displayName, businessName: businessName, localization: localization,
            booking: publishing.repository
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                Text("shareLink.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                if let message = viewModel.errorMessage {
                    ErrorNotice(message: message, actionTitle: "bookingSetup.dismiss", action: viewModel.dismissError)
                        .accessibilityIdentifier("shareLink.saveError")
                }
                address
                if let link = viewModel.savedLink, let texts = viewModel.texts {
                    publishNotice
                    qrCard(link: link, texts: texts)
                    actions(link: link, texts: texts)
                    whereToPutIt(texts: texts)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.bg)
        .navigationTitle(Text("shareLink.title"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.appear() }
        .task(id: viewModel.savedLink) { renderCard() }
    }

    // MARK: - Publishing

    /// Online (the link works), preview (it does not yet, with the button that puts her online) or the failure.
    @ViewBuilder
    private var publishNotice: some View {
        if case .error(let failure, let wasOnline) = publishing.state {
            PublishFailureNotice(failure: failure, wasOnline: wasOnline, onRetry: publishing.retry)
                .accessibilityIdentifier("shareLink.publishError")
        }
        if publishing.state.isLive {
            InlineNotice(style: .info, title: "shareLink.online.title", message: "shareLink.online.message")
                .accessibilityIdentifier("shareLink.online")
        } else {
            InlineNotice(style: .info, title: "shareLink.notOnline.title", message: "shareLink.notOnline.message")
                .accessibilityIdentifier("shareLink.notOnline")
            Button { publishing.goOnline() } label: {
                if case .publishing = publishing.state { ProgressView() } else { Text("publish.action.goOnline") }
            }
            .buttonStyle(.belloPrimary)
            .accessibilityIdentifier("shareLink.goOnlineButton")
        }
    }

    // MARK: - Address

    private var address: some View {
        SettingsSection(title: "shareLink.address.title") {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(verbatim: "\(viewModel.host)/").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                    .environment(\.layoutDirection, .leftToRight)
                    // The field below is labeled "Booking address"; the host in front of it is decoration.
                    .accessibilityHidden(true)
                BelloTextField(
                    title: "shareLink.address.field",
                    text: Binding(get: { viewModel.draft }, set: viewModel.updateDraft),
                    prompt: "shareLink.address.prompt", errorMessage: nil, isSensitive: true,
                    identifier: "shareLink.addressField"
                )
                statusLine
            }
            if !viewModel.suggestions.isEmpty && viewModel.draft.isEmpty {
                Text("shareLink.address.suggestions").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                    ForEach(viewModel.suggestions, id: \.self) { slug in
                        Button { viewModel.useSuggestion(slug) } label: { Text(verbatim: slug) }
                            .buttonStyle(.belloChip(selected: false))
                            .accessibilityIdentifier("shareLink.suggestion.\(slug)")
                    }
                }
            }
            saveButton
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch viewModel.status {
        case .idle:
            Text("shareLink.address.hint").font(Typography.footnote).foregroundStyle(Palette.ink2)
        case .checking:
            Text("shareLink.address.checking").font(Typography.footnote).foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("shareLink.addressStatus")
        case .available:
            Text("shareLink.address.available").font(Typography.footnoteStrong).foregroundStyle(Palette.sageText)
                .accessibilityIdentifier("shareLink.addressStatus")
        case .taken:
            Text("shareLink.address.taken").font(Typography.footnote).foregroundStyle(Palette.coralText)
                .accessibilityIdentifier("shareLink.addressStatus")
        case .reserved:
            Text("shareLink.address.reserved").font(Typography.footnote).foregroundStyle(Palette.coralText)
                .accessibilityIdentifier("shareLink.addressStatus")
        case .invalid(let issue):
            Text(issueText(issue)).font(Typography.footnote).foregroundStyle(Palette.coralText)
                .accessibilityIdentifier("shareLink.addressStatus")
        case .unchecked:
            Text("shareLink.address.offline").font(Typography.footnote).foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("shareLink.addressStatus")
        }
    }

    private var saveButton: some View {
        Button {
            Task { await viewModel.saveAddress() }
        } label: {
            if viewModel.isSavingAddress {
                ProgressView()
            } else {
                Text(viewModel.isAddressSaved ? "shareLink.address.saved" : "shareLink.address.save")
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(!viewModel.canSaveAddress)
        .accessibilityIdentifier("shareLink.saveAddressButton")
    }

    // MARK: - Link

    private func qrCard(link: BookingLink, texts: ShareTexts) -> some View {
        VStack(spacing: Spacing.row) {
            if let image = viewModel.qrImage {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                    .accessibilityElement()
                    .accessibilityLabel(Text(LocalizedStringResource(
                        "shareLink.qr.label", defaultValue: "QR code for \(link.display)"
                    ).localized(in: locale)))
                    .accessibilityIdentifier("shareLink.qr")
            }
            Text(verbatim: link.display).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityIdentifier("shareLink.linkText")
            Text(verbatim: texts.qrCaption).font(Typography.meta).foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func actions(link: BookingLink, texts: ShareTexts) -> some View {
        VStack(spacing: Spacing.row) {
            ShareLink(item: link.url, message: Text(verbatim: texts.shareMessage)) {
                Label { Text("shareLink.share") } icon: { Image(icon: .share) }
            }
            .buttonStyle(.belloPrimary)
            .accessibilityIdentifier("shareLink.shareButton")
            Button { viewModel.copyLink() } label: {
                Label {
                    Text(viewModel.copied == .link ? "shareLink.copied" : "shareLink.copy")
                } icon: { Image(icon: viewModel.copied == .link ? .check : .link) }
            }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("shareLink.copyButton")
            if let cardImage {
                ShareLink(
                    item: cardImage, preview: SharePreview(Text(verbatim: texts.cardTitle), image: cardImage)
                ) {
                    Label { Text("shareLink.card") } icon: { Image(icon: .download) }
                }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("shareLink.cardButton")
            }
        }
    }

    private func whereToPutIt(texts: ShareTexts) -> some View {
        SettingsSection(title: "shareLink.section.where") {
            CopyTextCard(
                icon: .globe, title: "shareLink.instagram.title", text: texts.instagramBio,
                isCopied: viewModel.copied == .instagram, identifier: "shareLink.instagramCopy",
                action: viewModel.copyInstagram
            )
            CopyTextCard(
                icon: .chat, title: "shareLink.whatsapp.title", subtitle: "shareLink.whatsapp.subtitle",
                text: texts.whatsAppGreeting, isCopied: viewModel.copied == .whatsApp,
                identifier: "shareLink.whatsappCopy", action: viewModel.copyWhatsApp
            )
        }
    }

    // MARK: - Words and drawing

    private func issueText(_ issue: SlugIssue) -> LocalizedStringKey {
        switch issue {
        case .tooShort: "shareLink.address.issue.tooShort"
        case .tooLong: "shareLink.address.issue.tooLong"
        case .characters: "shareLink.address.issue.characters"
        case .hyphenEdges: "shareLink.address.issue.hyphenEdges"
        case .doubleHyphen: "shareLink.address.issue.doubleHyphen"
        case .reserved: "shareLink.address.issue.reserved"
        }
    }

    private func renderCard() {
        guard let link = viewModel.savedLink, let texts = viewModel.texts, let qr = viewModel.qrImage else {
            cardImage = nil
            return
        }
        cardImage = TableCardRenderer.image(for: TableCardView(
            title: texts.cardTitle, subtitle: texts.cardSubtitle, displayLink: link.display, qr: qr
        ))
    }
}
