//
//  CancelPolicyView.swift
//  BelloHub
//

import SwiftUI

/// 6.16 Cancellations and changes. Her rules, set once and read by clients before they book: the free window, whether
/// and how often clients reschedule, what they may do after the window, the reminder and the grace for late arrivals,
/// then the exact text clients read. Everything saves as she taps. Pushed from the booking page settings, which hands
/// over the editor it shares with the no-show screen.
struct CancelPolicyView: View {
    @State private var viewModel: CancelPolicyViewModel
    private let editor: BookingSetupEditor
    private let localization: AppLocalization
    private let professionalName: String

    @Environment(\.locale) private var locale

    init(editor: BookingSetupEditor, localization: AppLocalization, professionalName: String) {
        self.editor = editor
        self.localization = localization
        self.professionalName = professionalName
        _viewModel = State(initialValue: CancelPolicyViewModel(
            editor: editor, localization: localization, professionalName: professionalName
        ))
    }

    private var formatters: Formatters {
        Formatters(locale: locale, timeZone: .current, currencyCode: "EUR")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                Text("cancelPolicy.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                if let message = viewModel.errorMessage {
                    ErrorNotice(message: message, actionTitle: "bookingSetup.dismiss", action: viewModel.dismissError)
                        .accessibilityIdentifier("cancelPolicy.saveError")
                }
                freeWindow
                rescheduling
                afterWindow
                reminder
                lateArrivals
                whatClientsRead
                related
                FooterNote(text: "cancelPolicy.footer", icon: .lock)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("cancelPolicy.title"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear { viewModel.appear() }
    }

    // MARK: - Sections

    private var freeWindow: some View {
        SettingsSection(title: "cancelPolicy.free.title", subtitle: "cancelPolicy.free.subtitle") {
            ChipChoice(
                options: CancellationPolicy.freeWindowOptions, selection: viewModel.policy.freeWindowHours,
                label: { formatters.hours($0) }, identifier: { "cancelPolicy.window.\($0)" },
                onSelect: viewModel.setFreeWindow
            )
        }
    }

    private var rescheduling: some View {
        SettingsSection(title: "cancelPolicy.reschedule.title") {
            ListCard(dividerInset: Spacing.md) {
                ToggleRow(
                    title: text("cancelPolicy.reschedule.toggle"),
                    subtitle: text("cancelPolicy.reschedule.toggleSubtitle"),
                    isOn: Binding(
                        get: { viewModel.policy.clientCanReschedule },
                        set: viewModel.setClientCanReschedule
                    ),
                    identifier: "cancelPolicy.rescheduleSwitch"
                )
            }
            if viewModel.policy.clientCanReschedule {
                Text("cancelPolicy.reschedule.times")
                    .font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                ChipChoice(
                    options: CancelPolicyViewModel.rescheduleOptions, selection: viewModel.policy.maxReschedules,
                    label: timesLabel, identifier: { "cancelPolicy.times.\($0.map(String.init) ?? "unlimited")" },
                    onSelect: viewModel.setMaxReschedules
                )
            }
        }
    }

    private var afterWindow: some View {
        SettingsSection(title: "cancelPolicy.after.title", subtitle: "cancelPolicy.after.subtitle") {
            Text("cancelPolicy.cancelling").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ChoiceCard(
                title: text("cancelPolicy.cancel.allow.title"), subtitle: text("cancelPolicy.cancel.allow.subtitle"),
                isSelected: viewModel.policy.afterWindowCancel == .allow, identifier: "cancelPolicy.cancel.allow",
                action: { viewModel.setAfterWindowCancel(.allow) }
            )
            ChoiceCard(
                title: text("cancelPolicy.cancel.message.title"),
                subtitle: text("cancelPolicy.cancel.message.subtitle"),
                isSelected: viewModel.policy.afterWindowCancel == .message, identifier: "cancelPolicy.cancel.message",
                action: { viewModel.setAfterWindowCancel(.message) }
            )
            Text(cancelNote).font(Typography.footnote).foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("cancelPolicy.cancelNote")
            if viewModel.policy.clientCanReschedule {
                Text("cancelPolicy.moving").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader).padding(.top, Spacing.sm)
                ChoiceCard(
                    title: text("cancelPolicy.move.request.title"),
                    subtitle: text("cancelPolicy.move.request.subtitle"),
                    isSelected: viewModel.policy.afterWindowReschedule == .request,
                    identifier: "cancelPolicy.move.request", action: { viewModel.setAfterWindowReschedule(.request) }
                )
                ChoiceCard(
                    title: text("cancelPolicy.move.message.title"),
                    subtitle: text("cancelPolicy.move.message.subtitle"),
                    isSelected: viewModel.policy.afterWindowReschedule == .message,
                    identifier: "cancelPolicy.move.message", action: { viewModel.setAfterWindowReschedule(.message) }
                )
            }
        }
    }

    private var reminder: some View {
        SettingsSection(title: "cancelPolicy.reminder.title") {
            ListCard(dividerInset: Spacing.md) {
                ToggleRow(
                    title: text("cancelPolicy.reminder.toggle"),
                    subtitle: text(
                        viewModel.policy.askConfirmation ? "cancelPolicy.reminder.on" : "cancelPolicy.reminder.off"
                    ),
                    isOn: Binding(get: { viewModel.policy.askConfirmation }, set: viewModel.setAskConfirmation),
                    identifier: "cancelPolicy.confirmSwitch"
                )
            }
        }
    }

    private var lateArrivals: some View {
        SettingsSection(title: "cancelPolicy.grace.title", subtitle: "cancelPolicy.grace.subtitle") {
            ChipChoice(
                options: CancelPolicyViewModel.graceOptions, selection: viewModel.policy.graceMinutes,
                label: { formatters.minutes($0) }, identifier: { "cancelPolicy.grace.\($0)" },
                onSelect: viewModel.setGraceMinutes
            )
        }
    }

    private var whatClientsRead: some View {
        SettingsSection(title: "cancelPolicy.read.title") {
            VStack(alignment: .leading, spacing: Spacing.row) {
                ForEach(Array(viewModel.ruleLines.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line).font(Typography.body).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Spacing.md)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("cancelPolicy.ruleText")
            Text("cancelPolicy.read.footer").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    private var related: some View {
        SettingsSection(title: "cancelPolicy.related") {
            ListCard(dividerInset: Spacing.md) {
                NavigationLink {
                    NoShowPolicyView(editor: editor, localization: localization, professionalName: professionalName)
                } label: {
                    MoreRow(
                        icon: .shield, tint: .rose, title: Text("bookingSettings.rules.noShow"),
                        subtitle: Text(noShowSummary), showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cancelPolicy.noShowRow")
            }
        }
    }

    // MARK: - Words

    private func text(_ key: String.LocalizationValue) -> String {
        String(localized: LocalizedStringResource(key, locale: locale))
    }

    private var cancelNote: LocalizedStringKey {
        switch viewModel.cancelNote {
        case .blocked: "cancelPolicy.cancel.note.blocked"
        case .counts: "cancelPolicy.cancel.note.counts"
        case .notCounted: "cancelPolicy.cancel.note.notCount"
        }
    }

    private func timesLabel(_ times: Int?) -> String {
        guard let times else { return text("cancelPolicy.times.unlimited") }
        return LocalizedStringResource("cancelPolicy.times", defaultValue: "\(times) times").resolved(in: locale)
    }

    private var noShowSummary: LocalizedStringResource {
        BookingSetupSummary.noShow(viewModel.noShow).localized(in: locale)
    }
}
