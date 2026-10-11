//
//  TimeZoneNoticeContent.swift
//  BelloHub
//

import SwiftUI

/// Owns the notice's ViewModel and wires its actions: the card's buttons on Home, and on Calendar a row that opens the
/// same three choices in a confirmation dialog (native, so the row stays one quiet line). Nothing changes without her
/// tap. "Language and region" opens that screen in the More tab.
struct TimeZoneNoticeContent: View {
    enum Placement {
        /// Home: the full card with its buttons.
        case card
        /// Calendar: one line; the choices open in a dialog.
        case row
    }

    @State private var viewModel: TimeZoneNoticeViewModel
    let placement: Placement
    let formatters: Formatters
    let now: Date

    @State private var showsChoices = false
    @Environment(MainNavigation.self) private var navigation: MainNavigation?
    @Environment(\.locale) private var locale
    @Environment(\.motionPolicy) private var motion

    init(viewModel: TimeZoneNoticeViewModel, placement: Placement, formatters: Formatters, now: Date) {
        _viewModel = State(initialValue: viewModel)
        self.placement = placement
        self.formatters = formatters
        self.now = now
    }

    /// No container around the notice: when there is nothing to say the screen's stack gets no empty view, so it keeps
    /// its spacing exactly as before.
    var body: some View {
        if let mismatch = viewModel.mismatch(now: now) {
            notice(mismatch)
                .transition(.opacity)
        }
    }

    // MARK: - Placements

    @ViewBuilder
    private func notice(_ mismatch: TimeZoneMismatch) -> some View {
        let text = TimeZoneNoticeText(mismatch: mismatch, formatters: formatters, now: now)
        let regionNote = viewModel.showsRegionNote(for: mismatch)
        switch placement {
        case .card:
            TimeZoneNoticeCard(
                text: text, showsRegionNote: regionNote, isSaving: viewModel.isSaving,
                errorMessage: viewModel.errorMessage,
                onUsePhoneZone: { viewModel.usePhoneZone(mismatch) },
                onKeep: { keep(mismatch) },
                onLanguageRegion: openLanguageRegion
            )
        case .row:
            VStack(alignment: .leading, spacing: Spacing.sm) {
                TimeZoneNoticeRow(text: text, isSaving: viewModel.isSaving) { showsChoices = true }
                if let message = viewModel.errorMessage {
                    ErrorNotice(message: message)
                        .padding(.horizontal, Spacing.gutter)
                        .accessibilityIdentifier("calendar.timeZoneNotice.error")
                }
            }
            .confirmationDialog(
                Text(text.headline.localized(in: locale)), isPresented: $showsChoices, titleVisibility: .visible
            ) {
                Button { viewModel.usePhoneZone(mismatch) } label: { Text("timeZoneNotice.usePhone") }
                    .accessibilityIdentifier("calendar.timeZoneNotice.usePhone")
                Button { keep(mismatch) } label: { Text("timeZoneNotice.keep") }
                    .accessibilityIdentifier("calendar.timeZoneNotice.keep")
                Button { openLanguageRegion() } label: { Text("timeZoneNotice.languageRegion") }
                    .accessibilityIdentifier("calendar.timeZoneNotice.languageRegion")
                Button(role: .cancel) { showsChoices = false } label: { Text("common.cancel") }
            } message: {
                Text(verbatim: dialogMessage(text, showsRegionNote: regionNote))
            }
        }
    }

    // MARK: - Private

    /// The dialog's message: the difference, what follows the business zone and, when it applies, the region note.
    private func dialogMessage(_ text: TimeZoneNoticeText, showsRegionNote: Bool) -> String {
        var lines = [
            text.difference.resolved(in: locale),
            LocalizedStringResource("timeZoneNotice.follows").resolved(in: locale)
        ]
        if showsRegionNote { lines.append(LocalizedStringResource("timeZoneNotice.regionNote").resolved(in: locale)) }
        return lines.joined(separator: "\n")
    }

    /// A short crossfade as the notice leaves (kept under Reduce Motion, none in UI tests: `MotionPolicy`).
    private func keep(_ mismatch: TimeZoneMismatch) {
        withAnimation(motion.allowsFade ? Motion.ease(Motion.Duration.fade) : nil) { viewModel.keep(mismatch) }
    }

    private func openLanguageRegion() {
        navigation?.selection = .more
        navigation?.morePath = [.languageRegion]
    }
}
