//
//  PrivacyContentView.swift
//  BelloHub
//

import SwiftUI

/// Where her data lives (this iPhone, her iCloud, the booking server), the recovery key with its status, the lock
/// and its timing, photos, lock-screen names, the export, retention, the legal texts and the no-analytics promise.
struct PrivacyContentView: View {
    @State private var viewModel: PrivacyViewModel

    @Environment(\.locale) private var locale

    init(
        lock: AppLockService, recoveryKey: RecoveryKeyService, notifications: NotificationSettingsService,
        localization: AppLocalization
    ) {
        _viewModel = State(initialValue: PrivacyViewModel(
            lock: lock, recoveryKey: recoveryKey, notifications: notifications, localization: localization
        ))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("privacy.subtitle").font(Typography.body).foregroundStyle(Palette.ink2)
                whereData
                recoveryKey
                lockSection
                photosAndNames
                clientData
                legal
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("privacy.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { viewModel.openedNotice != nil }, set: { if !$0 { viewModel.closeNotice() } }
        )) {
            if let notice = viewModel.openedNotice {
                LegalNoticeSheet(text: notice)
            }
        }
    }

    // MARK: - Sections

    private var whereData: some View {
        SettingsSection(title: "privacy.section.where") {
            ListCard(dividerInset: 72) {
                MoreRow(icon: .phone, tint: .sage, title: Text("privacy.where.phone"),
                        subtitle: Text("privacy.where.phone.subtitle"))
                MoreRow(icon: .cloud, tint: .peach, title: Text("privacy.where.icloud"),
                        subtitle: Text("privacy.where.icloud.subtitle"))
                MoreRow(icon: .globe, tint: .rose, title: Text("privacy.where.servers"),
                        subtitle: Text("privacy.where.servers.subtitle"))
                MoreRow(icon: .shield, tint: .sage, title: Text("privacy.where.analytics"),
                        subtitle: Text("privacy.where.analytics.subtitle"))
            }
        }
    }

    private var recoveryKey: some View {
        ListCard(dividerInset: 72) {
            NavigationLink(value: MoreRoute.recoveryKey) {
                MoreRow(
                    icon: .key, tint: .sage, title: Text("privacy.recoveryKey"), subtitle: recoveryLine,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("privacy.recoveryKeyRow")
        }
    }

    private var lockSection: some View {
        SettingsSection(title: "privacy.section.lock") {
            ListCard(dividerInset: Spacing.md) {
                ToggleRow(
                    title: String(localized: lockTitle), subtitle: String(localized: lockSubtitle),
                    isOn: Binding(get: { viewModel.lockEnabled }, set: viewModel.setLockEnabled),
                    identifier: "privacy.lockSwitch"
                )
                if viewModel.lockEnabled {
                    MenuPickerRow(
                        title: "privacy.lockAfter",
                        selection: Binding(get: { viewModel.graceSeconds }, set: viewModel.setGraceSeconds),
                        options: viewModel.graceOptions,
                        label: { String(localized: String.LocalizationValue(PrivacySummary.graceKey($0))) },
                        identifier: "privacy.lockAfterMenu"
                    )
                }
            }
        }
    }

    private var photosAndNames: some View {
        SettingsSection(title: "privacy.section.photosAndNames") {
            ListCard(dividerInset: 72) {
                MoreRow(icon: .camera, tint: .peach, title: Text("privacy.photos"),
                        subtitle: Text("privacy.photos.subtitle"))
                ToggleRow(
                    title: String(localized: "privacy.hideNames"),
                    subtitle: String(localized: "privacy.hideNames.subtitle"),
                    isOn: Binding(get: { viewModel.hideNames }, set: viewModel.setHideNames),
                    identifier: "privacy.hideNamesSwitch"
                )
            }
        }
    }

    private var clientData: some View {
        SettingsSection(title: "privacy.section.clientData") {
            VStack(alignment: .leading, spacing: Spacing.row) {
                ListCard(dividerInset: 72) {
                    NavigationLink(value: MoreRoute.exportAll) {
                        MoreRow(icon: .download, tint: .sage, title: Text("privacy.exportAll"),
                                subtitle: Text("privacy.exportAll.subtitle"), showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("privacy.exportAllRow")
                    MoreRow(icon: .user, tint: .neutral, title: Text("privacy.perClient"),
                            subtitle: Text("privacy.perClient.subtitle"))
                    MoreRow(icon: .clock, tint: .neutral, title: Text("privacy.retention"),
                            subtitle: Text("privacy.retention.subtitle"))
                }
                Text("privacy.clientData.note").font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
        }
    }

    private var legal: some View {
        SettingsSection(title: "privacy.section.legal") {
            VStack(alignment: .leading, spacing: Spacing.row) {
                if let message = viewModel.legalErrorMessage {
                    ErrorNotice(message: message).accessibilityIdentifier("privacy.legalError")
                }
                ListCard(dividerInset: 72) {
                    ForEach(LegalNotice.allCases) { notice in
                        Button { viewModel.open(notice) } label: {
                            MoreRow(icon: .document, tint: .neutral, title: Text(notice.title), showsChevron: true)
                        }
                        .accessibilityIdentifier("privacy.legal.\(notice.rawValue)")
                    }
                }
            }
        }
    }

    // MARK: - Texts

    private var recoveryLine: Text {
        let formatters = Formatters(locale: locale, timeZone: .current, currencyCode: "EUR")
        switch PrivacySummary.recoveryLine(viewModel.recoveryStatus, formatters: formatters) {
        case .notSaved:
            return Text("privacy.recoveryKey.notSaved")
        case .saved(let dateText):
            return Text(LocalizedStringResource(
                "privacy.recoveryKey.savedOn", defaultValue: "Saved on \(dateText)"
            ).localized(in: locale))
        }
    }

    private var lockTitle: LocalizedStringResource {
        switch viewModel.biometryKind {
        case .faceID: "privacy.lock.faceID"
        case .touchID: "privacy.lock.touchID"
        case .opticID: "privacy.lock.opticID"
        case .passcodeOnly: "privacy.lock.passcode"
        }
    }

    private var lockSubtitle: LocalizedStringResource {
        viewModel.biometryKind == .passcodeOnly ? "privacy.lock.passcode.subtitle" : "privacy.lock.subtitle"
    }
}
