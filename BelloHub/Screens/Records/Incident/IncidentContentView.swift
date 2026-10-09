//
//  IncidentContentView.swift
//  BelloHub
//

import SwiftUI

/// The body of 4.9: a clear, neutral note of a reaction (what happened, how serious, where, what she did, the visit it
/// belongs to), saved to the client's record. After saving it offers a check visit, which opens the agenda's new
/// appointment sheet for the same client.
struct IncidentContentView: View {
    @State private var viewModel: IncidentViewModel
    @State private var agendaSheet: AgendaSheet?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(clientID: UUID, appointmentID: UUID?, vault: VaultService, locale: Locale) {
        _viewModel = State(initialValue: IncidentViewModel(
            clientID: clientID, appointmentID: appointmentID, vault: vault,
            resolve: { $0.resolved(in: locale) }
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .background(Palette.bg)
                .navigationTitle(Text("incident.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Text("common.close") }
                            .accessibilityIdentifier("incident.closeButton")
                    }
                }
        }
        .task { await viewModel.loadAsync() }
        .agendaSheet(item: $agendaSheet)
        .presentationDetents([.large])
        .presentationBackground(Palette.bg)
        .interactiveDismissDisabled(viewModel.isWorking)
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .form: form
        case .saved: saved
        case .loading: RecordStateView(prefix: "incident", isMissing: false, errorMessage: nil, retry: viewModel.load)
        case .missing: RecordStateView(prefix: "incident", isMissing: true, errorMessage: nil, retry: viewModel.load)
        case .failed(let message):
            RecordStateView(prefix: "incident", isMissing: false, errorMessage: message, retry: viewModel.load)
        }
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("incident.intro").font(Typography.meta).foregroundStyle(Palette.ink2)
                if let message = viewModel.saveErrorMessage {
                    ErrorNotice(
                        message: message, actionTitle: "recordHistory.error.dismiss",
                        action: viewModel.dismissSaveError
                    )
                    .accessibilityIdentifier("incident.saveError")
                }
                clientRow
                symptoms
                severity
                area
                actions
                visit
                BelloNoteField(
                    title: Text("incident.notes"), text: $viewModel.draft.notes, prompt: "incident.notesPrompt",
                    isSensitive: true, identifier: "incident.notesField"
                )
                followUp
                FooterNote(text: "incident.lockNote", icon: .lock)
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.vertical, Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("incident.form")
        .safeAreaInset(edge: .bottom) { saveBar }
    }

    private var clientRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("incident.client").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: viewModel.client?.name ?? "").font(Typography.bodyStrong).foregroundStyle(Palette.ink)
                .accessibilityIdentifier("incident.clientName")
        }
    }

    private var symptoms: some View {
        ChoiceChips(
            title: "incident.what", options: IncidentSymptom.allCases,
            isSelected: { viewModel.draft.symptoms.contains($0) }, label: { $0.title.resolved(in: locale) },
            identifier: { "incident.symptom.\($0.rawValue)" }, onSelect: { viewModel.toggle($0) }
        )
    }

    private var severity: some View {
        ChoiceChips(
            title: "incident.severity", options: IncidentSeverity.allCases,
            isSelected: { viewModel.draft.severity == $0 }, label: { $0.title.resolved(in: locale) },
            identifier: { "incident.severity.\($0.rawValue)" }, onSelect: { viewModel.draft.severity = $0 }
        )
    }

    private var area: some View {
        ChoiceChips(
            title: "incident.area", options: IncidentArea.allCases,
            isSelected: { viewModel.draft.area == $0 }, label: { $0.title.resolved(in: locale) },
            identifier: { "incident.area.\($0.rawValue)" },
            onSelect: { viewModel.draft.area = viewModel.draft.area == $0 ? nil : $0 }
        )
    }

    private var actions: some View {
        ChoiceChips(
            title: "incident.did", options: IncidentAction.allCases,
            isSelected: { viewModel.draft.actions.contains($0) }, label: { $0.title.resolved(in: locale) },
            identifier: { "incident.action.\($0.rawValue)" }, onSelect: { viewModel.toggle($0) }
        )
    }

    /// The visit the note belongs to. "No visit" is a real choice: a reaction can be reported by phone days later.
    private var visit: some View {
        Picker(selection: $viewModel.draft.recordID) {
            Text("incident.visit.none").tag(UUID?.none)
            ForEach(viewModel.visits) { record in
                Text(verbatim: visitTitle(record)).tag(UUID?.some(record.id))
            }
        } label: {
            Text("incident.visit")
        }
        .pickerStyle(.menu)
        .tint(Palette.roseText)
        .frame(minHeight: Spacing.touchTarget)
        .accessibilityIdentifier("incident.visitPicker")
    }

    private func visitTitle(_ record: TreatmentRecord) -> String {
        let date = record.createdAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
        return "\(record.serviceName) · \(date)"
    }

    private var followUp: some View {
        ToggleRow(
            title: String(localized: "incident.followUp", locale: locale),
            subtitle: String(localized: "incident.followUp.detail", locale: locale),
            isOn: $viewModel.draft.followUp, identifier: "incident.followUpToggle"
        )
        .belloCard(cornerRadius: Radius.tile)
    }

    private var saveBar: some View {
        FlowBottomBar {
            Button { viewModel.save() } label: {
                if viewModel.isWorking { ProgressView() } else { Text("incident.save") }
            }
            .buttonStyle(.belloPrimary)
            .disabled(!viewModel.canSave)
            .accessibilityIdentifier("incident.saveButton")
            if !IncidentRules.canSave(viewModel.draft) {
                Text("incident.needsSymptom").font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
        }
    }

    // MARK: - Saved

    private var saved: some View {
        let name = viewModel.client?.name.split(separator: " ").first.map(String.init) ?? ""
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SuccessSeal().padding(.top, Spacing.xl)
                Text("incident.saved.title").font(Typography.title).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("incident.saved.title")
                Text(LocalizedStringResource(
                    "incident.saved.message",
                    defaultValue: "\(name)'s record now has this entry with today's date and time. It cannot be edited."
                ).localized(in: locale))
                    .font(Typography.meta).foregroundStyle(Palette.ink2)
                Button { agendaSheet = .newAppointment(clientID: viewModel.clientID, startsAt: nil) } label: {
                    Text("incident.saved.bookCheck")
                }
                .buttonStyle(.belloPrimary)
                .accessibilityIdentifier("incident.bookCheckButton")
                Button { dismiss() } label: { Text("incident.saved.done") }
                    .buttonStyle(.belloTertiary)
                    .accessibilityIdentifier("incident.doneButton")
            }
            .padding(.horizontal, Spacing.gutter)
        }
        .accessibilityIdentifier("incident.saved")
    }
}
