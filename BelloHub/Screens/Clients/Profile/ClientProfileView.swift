//
//  ClientProfileView.swift
//  BelloHub
//

import SwiftUI

/// 4.1 Client record: the center of following a client. Her name, contact and three small actions on top; allergies,
/// sensitivities and the important note when there are any; "Register visit" as the one primary action; then History
/// (open by default), Photos, Information and Documents. Export, incidents and editing sit in the actions menu.
struct ClientProfileView: View {
    let onOpen: (ClientsRoute) -> Void
    /// Pushes a record screen (the visit details) on the tab's stack. Defaults to nothing so a preview needs none.
    let onRecord: (RecordRoute) -> Void
    /// Presents a record sheet (incident, export, organizing photos).
    let onRecordSheet: (RecordSheet) -> Void
    /// Opens the visit flow full screen.
    let onVisitFlow: (TreatmentFlowRequest) -> Void
    /// Presents an agenda sheet (a message, a new booking).
    let onAgendaSheet: (AgendaSheet) -> Void

    @State private var viewModel: ClientProfileViewModel
    @State private var comparing: ComparedPhotos?
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale

    init(
        clientID: UUID, vault: VaultService, profile: ProfileService, onOpen: @escaping (ClientsRoute) -> Void,
        onRecord: @escaping (RecordRoute) -> Void = { _ in },
        onRecordSheet: @escaping (RecordSheet) -> Void = { _ in },
        onVisitFlow: @escaping (TreatmentFlowRequest) -> Void = { _ in },
        onAgendaSheet: @escaping (AgendaSheet) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: ClientProfileViewModel(clientID: clientID, vault: vault, profile: profile))
        self.onOpen = onOpen
        self.onRecord = onRecord
        self.onRecordSheet = onRecordSheet
        self.onVisitFlow = onVisitFlow
        self.onAgendaSheet = onAgendaSheet
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.snapshot != nil {
                    ToolbarItem(placement: .topBarTrailing) { actionsMenu }
                }
            }
            .task { viewModel.startListening() }
            .sheet(item: $comparing) { pair in
                PhotoCompareSheet(first: pair.first, second: pair.second, formatters: formatters,
                                  load: viewModel.fullPhoto(for:))
            }
            .alert(Text("clientProfile.call.failedTitle"), isPresented: callFailed) {
                Button(role: .cancel) {} label: { Text("common.close") }
            } message: {
                Text("clientProfile.call.failedMessage")
            }
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if let snapshot = viewModel.snapshot {
            overview(snapshot)
        } else if viewModel.isMissing {
            EmptyState(
                icon: .user, title: Text("clientProfile.missing.title"), message: Text("clientProfile.missing.message")
            )
            .accessibilityIdentifier("clientProfile.missing")
            .frame(maxHeight: .infinity)
        } else if let message = viewModel.errorMessage {
            EmptyState(
                icon: .alert, title: Text("clientProfile.error.title"), message: Text(message),
                actionTitle: "clientProfile.error.retry", action: viewModel.refresh
            )
            .accessibilityIdentifier("clientProfile.error")
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: Spacing.md) {
                Skeleton(height: 180, cornerRadius: Radius.hero)
                Skeleton(height: 56, cornerRadius: Radius.button)
                Skeleton(height: 140, cornerRadius: Radius.card)
                Spacer(minLength: 0)
            }
            .padding(Spacing.gutter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("clientProfile.loading"))
            .accessibilityIdentifier("clientProfile.loading")
        }
    }

    // MARK: - Overview

    private func overview(_ snapshot: ClientProfileSnapshot) -> some View {
        let now = Date()
        let client = snapshot.client
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ClientProfileHero(
                    client: client, chips: viewModel.chips, canCall: viewModel.canCall,
                    canMessage: viewModel.canMessage, onCall: viewModel.call,
                    onMessage: { onAgendaSheet(.clientMessage(.init(clientID: client.id, kind: .general))) },
                    onEdit: { onOpen(.edit(clientID: client.id)) }
                )
                if hasImportantNote(client) {
                    ImportantNoteCard(note: client.importantNote, allergies: client.allergies,
                                      sensitivities: client.sensitivities)
                }
                Button { onVisitFlow(viewModel.newVisitRequest) } label: {
                    Label { Text("clientRecord.register") } icon: { Image(icon: .compose) }
                }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("clientRecord.registerButton")
                if let plan = snapshot.plan {
                    SessionPlanCard(plan: plan, formatters: formatters)
                }
                ClientRecordSectionPicker(selection: $viewModel.section)
                    .padding(.top, Spacing.sm)
                section(snapshot, now: now)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .refreshable { await viewModel.refreshAsync() }
        .accessibilityIdentifier("clientProfile.overview")
    }

    @ViewBuilder
    private func section(_ snapshot: ClientProfileSnapshot, now: Date) -> some View {
        let clientID = snapshot.client.id
        switch viewModel.section {
        case .history:
            ClientHistorySection(
                timeline: viewModel.timeline, formatters: formatters, now: now,
                loadThumbnail: viewModel.thumbnail(for:), onOpenVisit: openVisit,
                onFillPending: { onVisitFlow(viewModel.pendingRecordRequest(for: $0)) },
                onOrganizePhotos: { onRecordSheet(.organizePhotos(clientID: clientID)) }
            )
        case .photos:
            ClientPhotosSection(
                timeline: viewModel.timeline, formatters: formatters, now: now,
                loadThumbnail: viewModel.thumbnail(for:), onOpenVisit: openVisit,
                onCompare: { comparing = ComparedPhotos(first: $0, second: $1) }
            )
        case .info:
            ClientInfoSection(
                snapshot: snapshot, formatters: formatters, now: now,
                onEditKnowledge: { onOpen(.knowledge(clientID: clientID)) },
                onEditDetails: { onOpen(.edit(clientID: clientID)) },
                onBook: { onAgendaSheet(.newAppointment(clientID: clientID, startsAt: nil)) }
            )
        case .documents:
            ClientDocumentsSection(
                snapshot: snapshot, timeline: viewModel.timeline, formatters: formatters,
                onOpenHealth: { onOpen(.health(clientID: clientID)) }
            )
        }
    }

    /// Edit, an incident without a visit, export: what she does to the record as a whole, out of the way.
    private var actionsMenu: some View {
        let clientID = viewModel.clientID
        return Menu {
            Button { onOpen(.edit(clientID: clientID)) } label: {
                Label { Text("clientRecord.menu.edit") } icon: { Image(icon: .pencil) }
            }
            .accessibilityIdentifier("clientRecord.menu.edit")
            Button { onAgendaSheet(.newAppointment(clientID: clientID, startsAt: nil)) } label: {
                Label { Text("clientRecord.menu.book") } icon: { Image(icon: .calendar) }
            }
            .accessibilityIdentifier("clientRecord.menu.book")
            Button { onRecordSheet(.incident(clientID: clientID, appointmentID: nil)) } label: {
                Label { Text("clientProfile.record.incident") } icon: { Image(icon: .alert) }
            }
            .accessibilityIdentifier("clientRecord.menu.incident")
            Button { onRecordSheet(.exportRecord(clientID: clientID)) } label: {
                Label { Text("clientProfile.record.export") } icon: { Image(icon: .share) }
            }
            .accessibilityIdentifier("clientRecord.menu.export")
        } label: {
            Image(icon: .ellipsis)
                .frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
        }
        .accessibilityLabel(Text("clientRecord.menu.label"))
        .accessibilityIdentifier("clientRecord.menu")
    }

    // MARK: - Helpers

    private func openVisit(_ visit: VisitSummary) {
        onRecord(.visit(recordID: visit.id))
    }

    private func hasImportantNote(_ client: Client) -> Bool {
        client.importantNote != nil || !client.allergies.isEmpty || !client.sensitivities.isEmpty
    }

    private var callFailed: Binding<Bool> {
        Binding(get: { viewModel.callFailed }, set: { if !$0 { viewModel.dismissCallFailure() } })
    }

    private var formatters: Formatters {
        let timeZone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return Formatters(locale: locale, timeZone: timeZone, currencyCode: profile.profile?.currencyCode ?? "USD")
    }
}

#if DEBUG
#Preview {
    ClientsPreviewHost { world in
        NavigationStack {
            ClientProfileView(clientID: world.seeded.ana, vault: world.vault, profile: world.profile, onOpen: { _ in })
        }
    }
}
#endif
