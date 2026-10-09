//
//  ServicesContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 6.1: a native `List`, because dragging, swipe actions and the edit-mode controls come with it and work
/// with VoiceOver, Switch Control and Dynamic Type for free. Tap a service to change it; swipe to switch it off or
/// delete it; Edit reorders. Below the list sit the two screens about what she offers besides services: add-ons and
/// products.
struct ServicesContentView: View {
    @State private var viewModel: ServicesViewModel
    @State private var editor: ServiceEditorMode?
    @State private var pendingDeletion: Service?
    @Environment(\.locale) private var locale
    private let profile: ProfileService

    init(repository: (any ServicesRepository)?, profile: ProfileService, locale: Locale) {
        self.profile = profile
        _viewModel = State(initialValue: ServicesViewModel(repository: repository, locale: locale))
    }

    var body: some View {
        list
            .background(Palette.bg)
            .navigationTitle(Text("services.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbar }
            .task { await viewModel.loadAsync() }
            .sheet(item: $editor) { mode in
                ServiceEditorSheet(mode: mode, viewModel: viewModel, formatters: formatters)
            }
            .deletionDialog(
                $pendingDeletion,
                title: { service in
                    Text(LocalizedStringResource(
                        "services.delete.title", defaultValue: "Delete “\(service.name)”?"
                    ).localized(in: locale))
                },
                message: { _ in Text("services.delete.message") },
                confirm: DeletionConfirm(title: "services.delete.confirm", identifier: "services.deleteConfirmButton"),
                onConfirm: { service in Task { await viewModel.delete(service) } }
            )
    }

    // MARK: - List

    private var list: some View {
        List {
            Section {
                Text("services.subtitle")
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    // A little inset: at none the first letter of a wrapped line is clipped by the list's edge.
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.sm, bottom: Spacing.sm, trailing: Spacing.sm))
            }
            notices
            servicesSection
            otherScreens
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.loadAsync() }
    }

    @ViewBuilder
    private var notices: some View {
        if let message = viewModel.errorMessage {
            Section {
                ErrorNotice(message: message, actionTitle: "services.retry", action: viewModel.load)
                    .accessibilityIdentifier("services.error")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        if let message = viewModel.saveErrorMessage {
            Section {
                ErrorNotice(message: message, actionTitle: "services.dismiss", action: viewModel.dismissSaveError)
                    .accessibilityIdentifier("services.saveError")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
    }

    // MARK: - Services

    @ViewBuilder
    private var servicesSection: some View {
        if viewModel.showsEmptyState {
            Section {
                EmptyState(
                    icon: .scissors, title: "services.empty.title", message: "services.empty.message",
                    actionTitle: "services.add", action: { editor = .add }
                )
                .accessibilityIdentifier("services.empty")
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        } else {
            filledServicesSection
        }
    }

    private var filledServicesSection: some View {
        Section {
            if viewModel.showsSkeleton {
                ForEach(0..<3, id: \.self) { _ in Skeleton(height: 72).listRowBackground(Palette.surface) }
            }
            ForEach(viewModel.services) { service in
                Button { editor = .edit(service) } label: { ServiceRow(service: service, formatters: formatters) }
                    .buttonStyle(.plain)
                    .listRowBackground(Palette.surface)
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) { swipeActions(for: service) }
                    .accessibilityIdentifier("services.row.\(service.id.uuidString)")
                    .accessibilityHint(Text("services.row.hint"))
            }
            .onMove { source, destination in viewModel.move(from: source, to: destination) }
            .onDelete { offsets in
                // The edit-mode minus lands here; she is asked before anything is deleted.
                pendingDeletion = offsets.first.map { viewModel.services[$0] }
            }
            if viewModel.hasLoaded { addRow }
        } header: {
            Text("services.section.yours")
                .font(Typography.section).foregroundStyle(Palette.ink)
                .textCase(nil)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private func swipeActions(for service: Service) -> some View {
        Button(role: .destructive) { pendingDeletion = service } label: { Text("services.delete.action") }
            .accessibilityIdentifier("services.deleteAction.\(service.id.uuidString)")
        Button { viewModel.setActive(!service.isActive, for: service) } label: {
            Text(service.isActive ? "services.switchOff" : "services.switchOn")
        }
        .tint(Palette.sage)
        .accessibilityIdentifier("services.activeAction.\(service.id.uuidString)")
    }

    private var addRow: some View {
        Button { editor = .add } label: {
            HStack(spacing: Spacing.row) {
                Image(icon: .plus)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("services.add").font(Typography.bodyStrong)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Palette.roseText)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.surface)
        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
        .accessibilityIdentifier("services.addRow")
    }

    // MARK: - The other two screens

    /// Add-ons and products, reached from here as in the prototype (and products from More as well). Each is a row of
    /// the list with its own link: two links inside one row would both fire on a tap.
    private var otherScreens: some View {
        Section {
            NavigationLink { AddOnsView() } label: {
                linkRow(
                    icon: .sparkle, title: Text("services.link.addOns"), subtitle: Text("services.link.addOns.subtitle")
                )
            }
            .listRowBackground(Palette.surface)
            .accessibilityIdentifier("services.addOnsLink")
            NavigationLink(value: MoreRoute.products) {
                linkRow(
                    icon: .box, title: Text("services.link.products"), subtitle: Text("services.link.products.subtitle")
                )
            }
            .listRowBackground(Palette.surface)
            .accessibilityIdentifier("services.productsLink")
        }
    }

    /// The label of one of the two rows. The list draws the chevron of a link itself.
    private func linkRow(icon: Icon, title: Text, subtitle: Text) -> some View {
        HStack(spacing: Spacing.row) {
            Image(icon: icon)
                .foregroundStyle(Palette.sageText)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
                .background(Palette.sageWash, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                title.font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                subtitle.font(Typography.meta).foregroundStyle(Palette.ink2)
            }
        }
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 64)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if viewModel.services.count > 1 {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton().accessibilityIdentifier("services.editButton")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { editor = .add } label: { Image(icon: .plus) }
                .accessibilityLabel(Text("services.add"))
                .accessibilityIdentifier("services.addButton")
        }
    }

    private var formatters: Formatters {
        let zone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return Formatters(locale: locale, timeZone: zone, currencyCode: profile.profile?.currencyCode ?? "USD")
    }
}
