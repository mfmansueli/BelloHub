//
//  VisitDetailContentView.swift
//  BelloHub
//

import SwiftUI

/// Everything about one visit: the day, the service and the record's state; its photos; every field she filled
/// (technique, products, her own fields, result and reaction, aftercare and what comes next); incidents and documents
/// tied to it; and, folded away at the end, the record's change history. From here she adds a photo, completes or
/// corrects the record, or uses it as the base of a new visit.
struct VisitDetailContentView: View {
    @State private var viewModel: VisitDetailViewModel
    @State private var visitFlow: TreatmentFlowRequest?
    @State private var recordSheet: RecordSheet?
    @State private var isReusing = false
    /// The new visit chosen in the reuse sheet, opened once that sheet is gone (one presentation at a time).
    @State private var pendingReuse: TreatmentFlowRequest?
    @State private var isSettingDay = false
    @State private var comparing: ComparedPhotos?
    @State private var showsHistory = false
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale

    init(recordID: UUID, vault: VaultService, profile: ProfileService) {
        _viewModel = State(initialValue: VisitDetailViewModel(recordID: recordID, vault: vault, profile: profile))
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("visitDetail.title"))
            .navigationSubtitle(Text(verbatim: viewModel.client?.name ?? ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.record != nil {
                    ToolbarItem(placement: .topBarTrailing) { menu }
                }
            }
            .task { viewModel.startListening() }
            .onDisappear { viewModel.stopListening() }
            .sheet(item: $viewModel.draft) { _ in RecordCorrectionSheet(viewModel: viewModel) }
            .sheet(isPresented: $isReusing, onDismiss: openPendingReuse) {
                if let record = viewModel.values?.applied {
                    ReuseVisitSheet(record: record) { parts in
                        pendingReuse = viewModel.reuseRequest(parts: parts)
                        isReusing = false
                    }
                }
            }
            .sheet(isPresented: $isSettingDay) { VisitDaySheet(viewModel: viewModel) }
            .sheet(item: $comparing) { pair in
                PhotoCompareSheet(first: pair.first, second: pair.second, formatters: formatters,
                                  load: viewModel.fullPhoto(for:))
            }
            .recordSheet(item: $recordSheet)
            .treatmentFlow(item: $visitFlow)
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        if let values = viewModel.values, let state = viewModel.state, let visitDate = viewModel.visitDate {
            overview(values: values, state: state, visitDate: visitDate)
        } else if viewModel.isMissing {
            EmptyState(icon: .document, title: "visitDetail.missing.title", message: "visitDetail.missing.message")
                .accessibilityIdentifier("visitDetail.missing")
                .frame(maxHeight: .infinity)
        } else if let message = viewModel.errorMessage {
            EmptyState(icon: .alert, title: Text("visitDetail.error.title"), message: Text(message),
                       actionTitle: "clientProfile.error.retry", action: viewModel.load)
                .accessibilityIdentifier("visitDetail.error")
                .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: Spacing.md) {
                Skeleton(height: 110, cornerRadius: Radius.card)
                Skeleton(height: 120, cornerRadius: Radius.card)
                Skeleton(height: 220, cornerRadius: Radius.card)
                Spacer(minLength: 0)
            }
            .padding(Spacing.gutter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("visitDetail.loading"))
            .accessibilityIdentifier("visitDetail.loading")
        }
    }

    private func overview(values: RecordCurrentValues, state: VisitRecordState, visitDate: RecordVisitDate)
        -> some View {
        let now = Date()
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VisitDetailHeader(record: values.record, visitDate: visitDate, state: state, formatters: formatters,
                                  now: now, onSetDay: { isSettingDay = true })
                if let message = viewModel.actionErrorMessage {
                    ErrorNotice(message: message, actionTitle: "recordHistory.error.dismiss",
                                action: viewModel.dismissActionError)
                }
                if state == .draft { draftNotice }
                VisitPhotosCard(
                    photos: viewModel.photos, formatters: formatters, loadThumbnail: viewModel.thumbnail(for:),
                    onAdd: openFlow, onCompare: { comparing = ComparedPhotos(first: $0, second: $1) }
                )
                VisitFieldsCard(values: values, entries: viewModel.entries)
                VisitLinksCard(incidents: viewModel.incidents, documents: viewModel.documents, formatters: formatters,
                               onReportIncident: reportIncident)
                actions(state: state)
                changeHistory
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .refreshable { await viewModel.loadAsync() }
        .accessibilityIdentifier("visitDetail.overview")
    }

    // MARK: - Sections

    private var draftNotice: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            InlineNotice(style: .info, title: "visitDetail.draft.title", message: "visitDetail.draft.message")
            Button(action: openFlow) {
                Label { Text("visitDetail.draft.continue") } icon: { Image(icon: .compose) }
            }
            .buttonStyle(.belloPrimary)
            .accessibilityIdentifier("visitDetail.continueButton")
        }
    }

    private func actions(state: VisitRecordState) -> some View {
        VStack(spacing: Spacing.sm) {
            if state != .draft {
                Button(action: complete) {
                    Label { Text("visitDetail.complete") } icon: { Image(icon: .pencil) }
                }
                .buttonStyle(.belloSecondary)
                .accessibilityIdentifier("visitDetail.completeButton")
            }
            Button { isReusing = true } label: {
                Label { Text("visitDetail.reuse") } icon: { Image(icon: .copy) }
            }
            .buttonStyle(.belloSecondary)
            .accessibilityIdentifier("visitDetail.reuseButton")
            if state == .locked {
                Text("visitDetail.lockedNote")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// The record's own story (created, finalized, locked, every correction), folded away: it is about the record,
    /// not about the client.
    private var changeHistory: some View {
        DisclosureGroup(isExpanded: $showsHistory) {
            VStack(alignment: .leading, spacing: 0) {
                let trail = viewModel.trail
                ForEach(Array(trail.enumerated()), id: \.element.id) { index, entry in
                    RecordTrailRow(entry: entry, formatters: formatters, professionalName: viewModel.professionalName,
                                   isLast: index == trail.count - 1)
                }
            }
            .padding(.top, Spacing.md)
        } label: {
            Label { Text("visitDetail.history") } icon: { Image(icon: .history) }
                .font(Typography.bodyStrong)
                .foregroundStyle(Palette.ink)
        }
        .tint(Palette.ink2)
        .padding(Spacing.md)
        .belloCard()
        .accessibilityIdentifier("visitDetail.history")
    }

    private var menu: some View {
        Menu {
            Button { isSettingDay = true } label: {
                Label { Text("visitDetail.setDay") } icon: { Image(icon: .calendar) }
            }
            Button(action: reportIncident) {
                Label { Text("clientProfile.record.incident") } icon: { Image(icon: .alert) }
            }
            if viewModel.state == .locked {
                Button { viewModel.beginCorrection() } label: {
                    Label { Text("recordHistory.addCorrection") } icon: { Image(icon: .plus) }
                }
            }
        } label: {
            Image(icon: .ellipsis).frame(width: Spacing.touchTarget, height: Spacing.touchTarget)
        }
        .accessibilityLabel(Text("clientRecord.menu.label"))
        .accessibilityIdentifier("visitDetail.menu")
    }

    // MARK: - Actions

    /// Continues a draft, or opens the visit flow to add photos or complete a record still open.
    private func openFlow() {
        visitFlow = viewModel.continueRequest
    }

    private func openPendingReuse() {
        guard let request = pendingReuse else { return }
        pendingReuse = nil
        visitFlow = request
    }

    /// A draft or an open record is completed in the flow; a locked one only by a logged correction.
    private func complete() {
        if viewModel.state == .locked {
            viewModel.beginCorrection()
        } else {
            openFlow()
        }
    }

    private func reportIncident() {
        guard let record = viewModel.record else { return }
        recordSheet = .incident(clientID: record.clientID, appointmentID: record.appointmentID, recordID: record.id)
    }

    private var formatters: Formatters {
        let timeZone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return Formatters(locale: locale, timeZone: timeZone, currencyCode: profile.profile?.currencyCode ?? "USD")
    }
}
