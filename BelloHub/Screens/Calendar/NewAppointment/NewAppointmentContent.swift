//
//  NewAppointmentContent.swift
//  BelloHub
//

import SwiftUI

/// The body of the New appointment sheet. Sections in the order she decides: who, what kind of visit, which service,
/// add-ons and guests, when. Warnings appear under the time and the primary button says "Book anyway" while one is
/// about the time; none of them blocks.
struct NewAppointmentContent: View {
    @State private var viewModel: NewAppointmentViewModel
    private let settings: CalendarSettings

    @State private var showsNewClient = false
    @State private var agendaSheet: AgendaSheet?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(ClientRegistrationService.self) private var registration

    private static let timeSectionID = "newAppointment.timeSection"

    init(viewModel: NewAppointmentViewModel, settings: CalendarSettings) {
        _viewModel = State(initialValue: viewModel)
        self.settings = settings
    }

    private var formatters: Formatters { settings.formatters(locale: locale) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let message = viewModel.errorMessage {
                            ErrorNotice(message: message, actionTitle: "scheduling.tryAgain") { viewModel.load() }
                                .padding(.top, Spacing.md)
                                .accessibilityIdentifier("newAppointment.error")
                        }
                        clientSection
                        visitTypeSection
                        serviceSection
                        durationRow
                        addOnsSection
                        guestsSection
                        timeSection.id(Self.timeSectionID)
                        warningsSection
                    }
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.bottom, Spacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    actionBar(scrollTo: { withAnimation { proxy.scrollTo(Self.timeSectionID) } })
                }
            }
            .background(Palette.bg)
            .navigationTitle(Text("newAppointment.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.cancel") }
                        .accessibilityIdentifier("newAppointment.cancelButton")
                }
            }
            .task { await viewModel.loadAsync() }
            .sheet(isPresented: $showsNewClient) { newClientSheet }
            .agendaSheet(item: $agendaSheet)
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
    }

    // MARK: - Sections

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "newAppointment.section.client")
            NewAppointmentClientCard(
                clients: viewModel.visibleClients, selectedID: viewModel.clientID, hasLoaded: viewModel.hasLoaded,
                searchText: $viewModel.searchText, onSelect: viewModel.selectClient,
                onNewClient: { showsNewClient = true }
            )
        }
    }

    private var visitTypeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "newAppointment.section.visitType")
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm) {
                ForEach(VisitType.allCases, id: \.self) { type in
                    Button { viewModel.visitType = type } label: { Text(type.schedulingTitle.localized(in: locale)) }
                        .buttonStyle(.belloChip(selected: viewModel.visitType == type))
                        .accessibilityAddTraits(viewModel.visitType == type ? .isSelected : [])
                        .accessibilityIdentifier("newAppointment.visitType.\(type.rawValue)")
                }
            }
        }
    }

    private var serviceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "newAppointment.section.service")
            if viewModel.services.isEmpty && viewModel.hasLoaded {
                Text("newAppointment.service.none")
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("newAppointment.service.none")
            }
            FlowLayout(spacing: Spacing.sm, lineSpacing: Spacing.sm, wrapsLongChildren: true) {
                ForEach(Array(viewModel.services.enumerated()), id: \.element.id) { index, service in
                    Button { viewModel.selectService(service.id) } label: { Text(verbatim: service.name) }
                        .buttonStyle(.belloChip(selected: viewModel.serviceID == service.id))
                        .accessibilityAddTraits(viewModel.serviceID == service.id ? .isSelected : [])
                        .accessibilityIdentifier("newAppointment.service.\(index)")
                }
            }
        }
    }

    private var durationRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("newAppointment.duration").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                Spacer(minLength: Spacing.sm)
                Text(verbatim: formatters.duration(minutes: viewModel.totalMinutes))
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("newAppointment.durationValue")
            }
            if viewModel.exceedsMaximumDuration {
                Text("newAppointment.duration.tooLong")
                    .font(Typography.footnote).foregroundStyle(Palette.coralText)
                    .accessibilityIdentifier("newAppointment.durationTooLong")
            }
        }
        .padding(.top, Spacing.md)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var addOnsSection: some View {
        if !viewModel.addOns.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "newAppointment.section.addOns")
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.addOns.enumerated()), id: \.element.id) { index, addOn in
                        if index > 0 { Divider().overlay(Palette.hairline) }
                        ToggleRow(
                            title: addOn.name, subtitle: "+ \(formatters.minutes(addOn.minutes))",
                            isOn: Binding(
                                get: { viewModel.addOnIDs.contains(addOn.id) },
                                set: { _ in viewModel.toggleAddOn(addOn.id) }
                            ),
                            identifier: "newAppointment.addOn.\(index)"
                        )
                    }
                }
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            }
        }
    }

    private var guestsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "newAppointment.section.guests")
            NewAppointmentGuestsSection(
                names: viewModel.guestNames, canAdd: viewModel.canAddGuest, onAdd: viewModel.addGuest,
                onRename: viewModel.setGuestName, onRemove: viewModel.removeGuest
            )
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "newAppointment.section.time")
            SchedulingTimeSection(
                idPrefix: "newAppointment", formatters: formatters, day: viewModel.day, start: viewModel.start,
                slots: viewModel.slots, moreSlots: viewModel.moreSlots, onSelectDay: viewModel.selectDay,
                onSelectStart: viewModel.selectStart, onSelectMinutes: viewModel.selectTime
            )
        }
    }

    @ViewBuilder
    private var warningsSection: some View {
        let entries = warningText.entries(for: viewModel.warnings)
        if !entries.isEmpty || viewModel.contextIsIncomplete {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SchedulingWarningsView(entries: entries, idPrefix: "newAppointment")
                if viewModel.contextIsIncomplete {
                    InlineNotice(style: .info, title: "newAppointment.incomplete.title",
                                 message: "newAppointment.incomplete.message")
                        .accessibilityIdentifier("newAppointment.incompleteNotice")
                }
            }
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Actions

    private func actionBar(scrollTo: @escaping () -> Void) -> some View {
        VStack(spacing: Spacing.sm) {
            if let message = viewModel.saveErrorMessage {
                ErrorNotice(message: message).accessibilityIdentifier("newAppointment.saveError")
            }
            Button(action: book) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Text(viewModel.hasScheduleConflict ? "newAppointment.bookAnyway" : "newAppointment.confirm")
                }
            }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canBook)
            .accessibilityIdentifier("newAppointment.confirmButton")
            if viewModel.hasScheduleConflict {
                HStack(spacing: Spacing.sm) {
                    Button(action: scrollTo) { Text("newAppointment.chooseAnother") }
                        .buttonStyle(.belloTertiary)
                        .accessibilityIdentifier("newAppointment.chooseAnotherButton")
                    Button { agendaSheet = .blockTime(day: viewModel.day) } label: {
                        Text("newAppointment.blockInstead")
                    }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("newAppointment.blockInsteadButton")
                }
            }
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .background(Palette.bg)
    }

    private func book() {
        Task {
            if await viewModel.bookAsync() { dismiss() }
        }
    }

    private var newClientSheet: some View {
        NewClientView(
            vault: vault, profile: profile, registrar: registration,
            regions: (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: []),
            onFinish: { finish in
                showsNewClient = false
                if case .registered(let id) = finish { Task { await viewModel.clientWasAdded(id) } }
            },
            onOpenExisting: { id in
                showsNewClient = false
                viewModel.selectClient(id)
            },
            onViewClients: { showsNewClient = false }
        )
    }

    private var warningText: SchedulingWarningText {
        SchedulingWarningText(
            clientName: viewModel.selectedClient?.name ?? "", serviceName: viewModel.selectedService?.name ?? "",
            neighbourName: { viewModel.clientName(for: $0) }, catalog: viewModel.context.catalog,
            formatters: formatters
        )
    }
}
