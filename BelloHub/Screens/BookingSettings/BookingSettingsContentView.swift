//
//  BookingSettingsContentView.swift
//  BelloHub
//

import SwiftUI

/// The booking page settings: her link, whether the page takes bookings (with the pause and its return date),
/// approval of new clients, guests per booking and the booking rules, with doors to her hours, her cancellation rules
/// and her no-show protection. Every switch saves as she taps it.
struct BookingSettingsContentView: View {
    @State private var viewModel: BookingSettingsViewModel
    @State private var showsPauseSheet = false
    @State private var confirmsStop = false
    let publishing: PublishingService

    @Environment(\.locale) private var locale

    init(
        service: BookingSetupService, publishing: PublishingService, profile: ProfessionalProfile?,
        services: (any AgendaRepository)? = nil
    ) {
        self.publishing = publishing
        _viewModel = State(initialValue: BookingSettingsViewModel(
            service: service, profile: profile, services: services
        ))
    }

    // MARK: - Helpers

    private var formatters: Formatters {
        Formatters(locale: locale, timeZone: viewModel.timeZone, currencyCode: "EUR")
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                notices
                linkSection
                takingBookings
                BookingRulesSection(viewModel: viewModel)
                SlotPreviewSection(viewModel: viewModel)
                FooterNote(text: "bookingSetup.footer.autosave", icon: .lock)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("bookingSettings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.loadAsync() }
        .task { await viewModel.loadAsync() }
        .onAppear { viewModel.appear() }
        .sheet(isPresented: $showsPauseSheet) {
            PauseSheet(viewModel: viewModel, formatters: formatters)
        }
        .confirmationDialog(
            Text("publish.stop.confirmTitle"), isPresented: $confirmsStop, titleVisibility: .visible
        ) {
            Button("publish.stop.confirm", role: .destructive) { Task { await publishing.stop() } }
                .accessibilityIdentifier("bookingSettings.stopConfirmButton")
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("publish.stop.confirmMessage")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var notices: some View {
        if let message = viewModel.errorMessage {
            ErrorNotice(message: message, actionTitle: "bookingSetup.retry", action: viewModel.load)
                .accessibilityIdentifier("bookingSettings.error")
        }
        if let message = viewModel.saveErrorMessage {
            ErrorNotice(message: message, actionTitle: "bookingSetup.dismiss", action: viewModel.dismissSaveError)
                .accessibilityIdentifier("bookingSettings.saveError")
        }
        if case .error(let failure, let wasOnline) = publishing.state {
            PublishFailureNotice(failure: failure, wasOnline: wasOnline, onRetry: publishing.retry)
                .accessibilityIdentifier("bookingSettings.publishError")
        }
    }

    private var linkSection: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            BookingLinkCard(
                link: viewModel.link,
                shareMessage: ShareTexts(
                    localization: viewModel.localization, professionalName: viewModel.professionalName,
                    displayLink: viewModel.link?.display ?? ""
                ).shareMessage,
                isCopied: viewModel.copiedLink, state: publishing.state, onCopy: viewModel.copyLink,
                onGoOnline: publishing.goOnline
            ) {
                NavigationLink { shareLinkScreen } label: { Text("bookingSettings.link.noAddress") }
            }
            ListCard(dividerInset: 72) {
                NavigationLink { shareLinkScreen } label: {
                    MoreRow(icon: .qr, tint: .rose, title: Text("bookingSettings.link.more"), showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bookingSettings.shareRow")
            }
            if publishing.state.isLive { stopButton }
        }
    }

    private var stopButton: some View {
        Button { confirmsStop = true } label: { Text("publish.action.stop") }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("bookingSettings.stopButton")
    }

    private var shareLinkScreen: some View {
        ShareLinkView(
            editor: viewModel.editor, publishing: publishing, displayName: viewModel.displayName,
            businessName: viewModel.businessName, localization: viewModel.localization
        )
    }

    private var takingBookings: some View {
        SettingsSection(title: "bookingSettings.section.taking") {
            ListCard(dividerInset: Spacing.md) {
                ToggleRow(
                    title: text("bookingSettings.accepting.title"),
                    subtitle: text(viewModel.isAccepting
                                   ? "bookingSettings.accepting.subtitle" : "bookingSettings.accepting.pausedSubtitle"),
                    isOn: Binding(
                        get: { viewModel.isAccepting },
                        set: { open in
                            if open { Task { await viewModel.resume() } } else { showsPauseSheet = true }
                        }
                    ),
                    identifier: "bookingSettings.acceptingSwitch"
                )
                if !viewModel.isAccepting { pauseDetails }
                ToggleRow(
                    title: text("bookingSettings.confirmNew.title"),
                    subtitle: text("bookingSettings.confirmNew.subtitle"),
                    isOn: Binding(
                        get: { viewModel.setup.page.confirmNewClients }, set: viewModel.setConfirmNewClients
                    ),
                    identifier: "bookingSettings.confirmNewSwitch"
                )
                guestsRow
            }
        }
    }

    /// While paused: the return date (or "not sure yet"), the way to change it and the way to open bookings again.
    private var pauseDetails: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            if let returnDate = viewModel.returnDate {
                datePickerRow(returnDate)
                Button { Task { await viewModel.setReturnDate(nil) } } label: {
                    Text("bookingSettings.backOn.clear").font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                        .frame(minHeight: Spacing.touchTarget)
                }
                .accessibilityIdentifier("bookingSettings.clearReturnDateButton")
            } else {
                noReturnDateRow
            }
            Text("bookingSettings.paused.note").font(Typography.footnote).foregroundStyle(Palette.ink2)
            Button { Task { await viewModel.resume() } } label: { Text("bookingSettings.resume") }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("bookingSettings.resumeButton")
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func datePickerRow(_ returnDate: Date) -> some View {
        DatePicker(
            selection: Binding(get: { returnDate }, set: { date in Task { await viewModel.setReturnDate(date) } }),
            in: viewModel.earliestReturnDate..., displayedComponents: .date
        ) {
            Text("bookingSettings.backOn").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
        }
        .environment(\.timeZone, formatters.timeZone)
        .environment(\.calendar, formatters.calendar)
        .accessibilityIdentifier("bookingSettings.returnDatePicker")
    }

    @ViewBuilder
    private var noReturnDateRow: some View {
        HStack {
            Text("bookingSettings.backOn").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            Spacer(minLength: Spacing.sm)
            Text("bookingSettings.backOn.none").font(Typography.body).foregroundStyle(Palette.ink2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("bookingSettings.noReturnDate")
        Button {
            let week = formatters.calendar.date(byAdding: .day, value: 7, to: viewModel.earliestReturnDate)
            Task { await viewModel.setReturnDate(week) }
        } label: {
            Text("bookingSettings.pauseSheet.chooseDate").font(Typography.metaStrong)
                .foregroundStyle(Palette.roseText).frame(minHeight: Spacing.touchTarget)
        }
        .accessibilityIdentifier("bookingSettings.chooseReturnDateButton")
    }

    private var guestsRow: some View {
        Stepper(
            value: Binding(get: { viewModel.setup.page.maxGuests }, set: viewModel.setMaxGuests),
            in: BookingPageSettings.guestRange
        ) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("bookingSettings.guests.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text("bookingSettings.guests.subtitle").font(Typography.meta).foregroundStyle(Palette.ink2)
                Text(guestsValue).font(Typography.metaStrong).foregroundStyle(Palette.ink)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .accessibilityValue(Text(guestsValue))
        .accessibilityIdentifier("bookingSettings.guestsStepper")
    }

    // MARK: - Words

    private func text(_ key: String.LocalizationValue) -> String {
        String(localized: LocalizedStringResource(key, locale: locale))
    }

    private var guestsValue: String {
        let guests = viewModel.setup.page.maxGuests
        guard guests > 0 else { return text("bookingSettings.guests.none") }
        return LocalizedStringResource("bookingSettings.guests.count", defaultValue: "\(guests) guests")
            .resolved(in: locale)
    }
}
