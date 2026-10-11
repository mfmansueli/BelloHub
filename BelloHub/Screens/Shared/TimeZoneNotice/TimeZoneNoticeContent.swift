//
//  TimeZoneNoticeContent.swift
//  BelloHub
//

import SwiftUI

/// Owns the notice's ViewModel and wires its actions: the card's buttons on Home, and on Calendar a row that opens the
/// same three choices in a native menu, so the row stays one quiet line. Nothing changes without her
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
                choicesMenu(mismatch, text: text, showsRegionNote: regionNote)
                if let message = viewModel.errorMessage {
                    ErrorNotice(message: message)
                        .padding(.horizontal, Spacing.gutter)
                        .accessibilityIdentifier("calendar.timeZoneNotice.error")
                }
            }
        }
    }

    /// The row opens a native menu with the same choices as the card. The menu's section titles carry the difference
    /// and, when it applies, the region note, so the row itself stays one quiet line.
    private func choicesMenu(_ mismatch: TimeZoneMismatch, text: TimeZoneNoticeText, showsRegionNote: Bool) -> some View {
        Menu {
            Section {
                Button { viewModel.usePhoneZone(mismatch) } label: { Text("timeZoneNotice.usePhone") }
                    .accessibilityIdentifier("calendar.timeZoneNotice.usePhone")
                Button { keep(mismatch) } label: { Text("timeZoneNotice.keep") }
                    .accessibilityIdentifier("calendar.timeZoneNotice.keep")
            } header: {
                Text(text.difference.localized(in: locale))
            }
            Section {
                Button { openLanguageRegion() } label: { Text("timeZoneNotice.languageRegion") }
                    .accessibilityIdentifier("calendar.timeZoneNotice.languageRegion")
            } header: {
                if showsRegionNote { Text("timeZoneNotice.regionNote") }
            }
        } label: {
            TimeZoneNoticeRow(text: text, isSaving: viewModel.isSaving)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSaving)
        .accessibilityHint(Text("timeZoneNotice.row.hint"))
        .accessibilityIdentifier("calendar.timeZoneNotice")
    }

    // MARK: - Private

    /// A short crossfade as the notice leaves (kept under Reduce Motion, none in UI tests: `MotionPolicy`).
    private func keep(_ mismatch: TimeZoneMismatch) {
        withAnimation(motion.allowsFade ? Motion.ease(Motion.Duration.fade) : nil) { viewModel.keep(mismatch) }
    }

    private func openLanguageRegion() {
        navigation?.selection = .more
        navigation?.morePath = [.languageRegion]
    }
}
