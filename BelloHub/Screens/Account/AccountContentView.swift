//
//  AccountContentView.swift
//  BelloHub
//

import SwiftUI

/// Her profile (name, business name, phone, profession, region and booking link), Language and region, sign-out and
/// the delete-account flow. The avatar shows her initials: v1 has no profile photo (see the S10 notes).
struct AccountContentView: View {
    @State private var viewModel: AccountViewModel
    @State private var confirmsSignOut = false

    @Environment(\.locale) private var locale
    @Environment(BookingSetupService.self) private var bookingSetup

    init(profile: ProfileService, account: AccountService, session: SessionService, onSignOut: @escaping () -> Void) {
        _viewModel = State(initialValue: AccountViewModel(
            profile: profile, account: account, session: session, signOut: onSignOut
        ))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                notices
                profileSection
                factsSection
                preferencesSection
                sessionSection
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.bg)
        .navigationTitle(Text("account.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: viewModel.save) { Text("account.save") }
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("account.saveButton")
            }
        }
        .confirmationDialog(
            Text("more.signOut.confirmTitle"), isPresented: $confirmsSignOut, titleVisibility: .visible
        ) {
            Button(role: .destructive, action: viewModel.confirmSignOut) { Text("more.signOut.confirm") }
                .accessibilityIdentifier("account.signOutConfirmButton")
            Button(role: .cancel) {} label: { Text("common.cancel") }
        } message: {
            Text("more.signOut.confirmMessage")
        }
        .sheet(isPresented: deletionSheetBinding) {
            DeleteAccountSheet(viewModel: viewModel)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Avatar(name: viewModel.displayName, id: viewModel.stored?.id.uuidString ?? "", size: 72)
            Text("account.photo.note").font(Typography.meta).foregroundStyle(Palette.ink2)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var notices: some View {
        if let message = viewModel.errorMessage {
            ErrorNotice(message: message).accessibilityIdentifier("account.error")
        }
        if viewModel.saved {
            InlineNotice(style: .info, title: "account.saved")
                .accessibilityIdentifier("account.savedNotice")
                .task {
                    try? await Task.sleep(for: .seconds(3))
                    viewModel.dismissSaved()
                }
        }
    }

    private var profileSection: some View {
        SettingsSection(title: "account.section.profile") {
            VStack(spacing: Spacing.row) {
                BelloTextField(
                    title: "account.field.name", text: $viewModel.displayName,
                    errorMessage: nameError(viewModel.nameIssue), identifier: "account.nameField"
                )
                BelloTextField(
                    title: "account.field.businessName", text: $viewModel.businessName,
                    prompt: "account.field.businessName.prompt",
                    errorMessage: nameError(viewModel.businessNameIssue), identifier: "account.businessNameField"
                )
            }
        }
    }

    /// What she cannot change here: her phone (sign-in), profession (setup) and the booking address.
    private var factsSection: some View {
        SettingsSection(title: "account.section.details") {
            ListCard(dividerInset: Spacing.md) {
                factRow("account.field.phone", value: phoneText, identifier: "account.phoneRow")
                factRow("account.field.profession", value: professionText, identifier: "account.professionRow")
                bookingLinkRow
            }
        }
    }

    private var preferencesSection: some View {
        SettingsSection(title: "account.section.preferences") {
            ListCard(dividerInset: 72) {
                NavigationLink(value: MoreRoute.languageRegion) {
                    MoreRow(
                        icon: .globe, tint: .sage, title: Text("account.row.languageRegion"),
                        subtitle: Text(verbatim: regionText), showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("account.languageRegionRow")
            }
        }
    }

    private var sessionSection: some View {
        SettingsSection(title: "account.section.session") {
            ListCard(dividerInset: 72) {
                Button { confirmsSignOut = true } label: {
                    MoreRow(
                        icon: .logout, tint: .neutral, title: Text("more.signOut"),
                        subtitle: Text("account.signOut.subtitle")
                    )
                }
                .accessibilityIdentifier("account.signOutButton")
                Button { viewModel.send(.tappedDelete) } label: {
                    MoreRow(
                        icon: .trash, tint: .rose, title: Text("account.delete"),
                        subtitle: Text("account.delete.subtitle")
                    )
                }
                .accessibilityIdentifier("account.deleteButton")
            }
        }
    }

    // MARK: - Parts

    private func factRow(_ title: LocalizedStringKey, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title).font(Typography.meta).foregroundStyle(Palette.ink2)
            Text(verbatim: value.isEmpty ? "—" : value).font(Typography.body).foregroundStyle(Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    /// Her booking link. Pressing and holding it offers Copy, the iOS way to copy a line of text; the row says
    /// "Copied" for a moment and the haptic confirms it.
    private var bookingLinkRow: some View {
        let link = bookingSetup.setup.slug.map { BookingLink(slug: $0) }
        return factRow(
            "account.field.bookingLink", value: viewModel.copiedLink ? copiedText : bookingLinkText,
            identifier: "account.bookingLinkRow"
        )
        .contentShape(.rect)
        .contextMenu {
            if let link {
                Button { viewModel.copyBookingLink(link) } label: {
                    Label { Text("bookingSettings.link.copy") } icon: { Image(icon: .link) }
                }
                .accessibilityIdentifier("account.bookingLinkCopyButton")
            }
        }
        .sensoryFeedback(.success, trigger: viewModel.copiedLink) { _, copied in copied }
        .accessibilityAction(named: Text("bookingSettings.link.copy")) {
            if let link { viewModel.copyBookingLink(link) }
        }
    }

    private var copiedText: String {
        String(localized: LocalizedStringResource("bookingSettings.link.copied").localized(in: locale))
    }

    private func nameError(_ issue: AccountRules.NameIssue?) -> LocalizedStringKey? {
        switch issue {
        case .empty: "account.error.nameEmpty"
        case .tooLong: "account.error.nameTooLong"
        case nil: nil
        }
    }

    private var deletionSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.deletion != .idle },
            set: { presented in if !presented { viewModel.send(.cancelled) } }
        )
    }

    private var phoneText: String {
        guard let phone = viewModel.phoneE164, let catalog = try? RegionCatalog.loadBundled() else {
            return viewModel.phoneE164 ?? ""
        }
        return PhoneFormatter(catalog: catalog).international(phone)
    }

    private var professionText: String {
        guard let current = viewModel.stored else { return "" }
        let localization = AppLocalization(rawValue: current.appLocaleID) ?? .en
        let catalog = try? ProfessionCatalog.loadBundled(localization: localization)
        return current.professions.compactMap { catalog?.entry(for: $0)?.name }.joined(separator: " · ")
    }

    private var bookingLinkText: String {
        bookingSetup.setup.slug.map { BookingLink(slug: $0).display } ?? ""
    }

    private var regionText: String {
        guard let current = viewModel.stored else { return "" }
        let region = locale.localizedString(forRegionCode: current.regionCode) ?? current.regionCode
        let language = AppLocalization(rawValue: current.appLocaleID)?.nativeName ?? current.appLocaleID
        return "\(region) · \(language)"
    }
}
