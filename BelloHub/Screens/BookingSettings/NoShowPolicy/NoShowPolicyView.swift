//
//  NoShowPolicyView.swift
//  BelloHub
//

import SwiftUI

/// 6.15 No-show protection. A switch for the protection, how many no-shows a client may have, whether a late
/// cancellation counts, how long a no-show counts and what happens at the limit, then the sentence clients read.
/// Everything saves as she taps. Pushed from the booking page settings or the cancellation screen, which hand over
/// the shared editor.
struct NoShowPolicyView: View {
    @State private var viewModel: NoShowPolicyViewModel
    private let editor: BookingSetupEditor
    private let localization: AppLocalization
    private let professionalName: String

    @Environment(\.locale) private var locale

    init(editor: BookingSetupEditor, localization: AppLocalization, professionalName: String) {
        self.editor = editor
        self.localization = localization
        self.professionalName = professionalName
        _viewModel = State(initialValue: NoShowPolicyViewModel(
            editor: editor, localization: localization, professionalName: professionalName
        ))
    }

    private var formatters: Formatters {
        Formatters(locale: locale, timeZone: .current, currencyCode: "EUR")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                Text("noShowPolicy.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                if let message = viewModel.errorMessage {
                    ErrorNotice(message: message, actionTitle: "bookingSetup.dismiss", action: viewModel.dismissError)
                        .accessibilityIdentifier("noShowPolicy.saveError")
                }
                InlineNotice(style: .info, title: "policy.fromBooking.note")
                    .accessibilityIdentifier("noShowPolicy.fromBookingNote")
                protection
                if viewModel.policy.isOn {
                    limit
                    counts
                    period
                    action
                    messages
                } else {
                    InlineNotice(style: .info, title: "noShowPolicy.off.note")
                        .accessibilityIdentifier("noShowPolicy.offNote")
                }
                if let line = viewModel.ruleLine { whatClientsRead(line) }
                FooterNote(text: "noShowPolicy.footer", icon: .lock)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("noShowPolicy.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.appear() }
    }

    // MARK: - Sections

    private var protection: some View {
        ListCard(dividerInset: Spacing.md) {
            ToggleRow(
                title: text("noShowPolicy.master.title"), subtitle: text("noShowPolicy.master.subtitle"),
                isOn: Binding(get: { viewModel.policy.isOn }, set: viewModel.setOn),
                identifier: "noShowPolicy.masterSwitch"
            )
        }
    }

    private var limit: some View {
        SettingsSection(title: "noShowPolicy.limit.section") {
            ListCard(dividerInset: Spacing.md) {
                Stepper(
                    value: Binding(get: { viewModel.policy.limit }, set: viewModel.setLimit),
                    in: NoShowPolicy.limitRange
                ) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("noShowPolicy.limit.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                        Text("noShowPolicy.limit.subtitle").font(Typography.meta).foregroundStyle(Palette.ink2)
                        Text(verbatim: formatters.number(viewModel.policy.limit))
                            .font(Typography.numeral).foregroundStyle(Palette.ink)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .accessibilityValue(Text(verbatim: formatters.number(viewModel.policy.limit)))
                .accessibilityIdentifier("noShowPolicy.limitStepper")
            }
        }
    }

    private var counts: some View {
        SettingsSection(title: "noShowPolicy.counts.section") {
            ListCard(dividerInset: Spacing.md) {
                missedRow
                ToggleRow(
                    title: LocalizedStringResource(
                        "noShowPolicy.counts.late.title",
                        defaultValue: "Cancelled inside \(formatters.hours(viewModel.cancellation.freeWindowHours))"
                    ).resolved(in: locale),
                    subtitle: text("noShowPolicy.counts.late.subtitle"),
                    isOn: Binding(get: { viewModel.policy.lateCancelCounts }, set: viewModel.setLateCancelCounts),
                    identifier: "noShowPolicy.lateSwitch"
                )
                NavigationLink {
                    CancelPolicyView(editor: editor, localization: localization, professionalName: professionalName)
                } label: {
                    HStack {
                        Text("noShowPolicy.counts.late.link")
                            .font(Typography.bodyStrong).foregroundStyle(Palette.roseText)
                        Spacer(minLength: 0)
                        Image(icon: .forward).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink3)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("noShowPolicy.freePeriodRow")
            }
        }
    }

    private var missedRow: some View {
        HStack(spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("noShowPolicy.counts.missed.title").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Text("noShowPolicy.counts.missed.subtitle").font(Typography.meta).foregroundStyle(Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("noShowPolicy.counts.missed.badge")
                .font(Typography.caption).foregroundStyle(Palette.sageText)
                .padding(.horizontal, Spacing.row).padding(.vertical, Spacing.xs)
                .background(Palette.sageWash, in: Capsule())
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 64)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("noShowPolicy.missedRow")
    }

    private var period: some View {
        SettingsSection(title: "noShowPolicy.period.section", subtitle: "noShowPolicy.period.footer") {
            ChipChoice(
                options: NoShowPolicy.countingMonthOptions, selection: viewModel.policy.countingMonths,
                label: monthsLabel,
                identifier: { "noShowPolicy.period.\($0)" }, onSelect: viewModel.setCountingMonths
            )
        }
    }

    private var action: some View {
        SettingsSection(title: "noShowPolicy.action.section") {
            actionCard(.tell, title: "noShowPolicy.action.tell.title", subtitle: "noShowPolicy.action.tell.subtitle",
                       identifier: "noShowPolicy.action.tell")
            actionCard(.approveNewBookings, title: "noShowPolicy.action.approve.title",
                       subtitle: "noShowPolicy.action.approve.subtitle", identifier: "noShowPolicy.action.approve")
            actionCard(.pauseOnline, title: "noShowPolicy.action.pause.title",
                       subtitle: "noShowPolicy.action.pause.subtitle", identifier: "noShowPolicy.action.pause")
        }
    }

    private var messages: some View {
        ListCard(dividerInset: Spacing.md) {
            // A closure link, not the typed route: this screen can be reached from the cancellation screen, which is
            // itself pushed by closure, and a typed push from there would not land on the More stack.
            NavigationLink {
                QuickRepliesView()
            } label: {
                MoreRow(
                    icon: .chat, tint: .sage, title: Text("noShowPolicy.messages.title"),
                    subtitle: Text("noShowPolicy.messages.subtitle"), showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("noShowPolicy.messagesRow")
        }
    }

    private func whatClientsRead(_ line: String) -> some View {
        SettingsSection(title: "noShowPolicy.read.title") {
            Text(verbatim: line).font(Typography.body).foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .accessibilityIdentifier("noShowPolicy.ruleText")
            Text("noShowPolicy.read.footer").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    // MARK: - Parts

    private func actionCard(
        _ value: NoShowAction, title: String.LocalizationValue, subtitle: String.LocalizationValue, identifier: String
    ) -> some View {
        ChoiceCard(
            title: text(title), subtitle: text(subtitle), isSelected: viewModel.policy.action == value,
            identifier: identifier, action: { viewModel.setAction(value) }
        )
    }

    private func monthsLabel(_ months: Int) -> String {
        LocalizedStringResource("noShowPolicy.period.months", defaultValue: "\(months) months").resolved(in: locale)
    }

    private func text(_ key: String.LocalizationValue) -> String {
        String(localized: LocalizedStringResource(key, locale: locale))
    }
}
