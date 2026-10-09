//
//  ClientProfileView.swift
//  BelloHub
//

import SwiftUI

/// 4.1 ClientProfile. Her name and what the vault says about her at a glance: the important note, her session plan,
/// the last and next visit, what she remembers about her, the health and consent line and her habits. Record history,
/// photos, products, no-show history, export and incidents join it with their own stages.
struct ClientProfileView: View {
    let onOpen: (ClientsRoute) -> Void

    @State private var viewModel: ClientProfileViewModel
    @Environment(ProfileService.self) private var profile
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(clientID: UUID, vault: VaultService, profile: ProfileService, onOpen: @escaping (ClientsRoute) -> Void) {
        _viewModel = State(initialValue: ClientProfileViewModel(clientID: clientID, vault: vault, profile: profile))
        self.onOpen = onOpen
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.snapshot != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { onOpen(.edit(clientID: viewModel.clientID)) } label: { Text("clientProfile.edit") }
                            .accessibilityIdentifier("clientProfile.editButton")
                    }
                }
            }
            .task { viewModel.startListening() }
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
                Skeleton(height: 220, cornerRadius: Radius.hero)
                Skeleton(height: 90, cornerRadius: Radius.card)
                Skeleton(height: 90, cornerRadius: Radius.card)
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
            StaggeredStack(spacing: Spacing.lg) {
                ClientProfileHero(
                    client: client, chips: viewModel.chips, canCall: viewModel.canCall, onCall: viewModel.call
                )
                if hasImportantNote(client) {
                    ImportantNoteCard(note: client.importantNote, allergies: client.allergies)
                }
                if let plan = snapshot.plan {
                    SessionPlanCard(plan: plan, formatters: formatters)
                }
                visitTiles(snapshot, now: now)
                VStack(alignment: .leading, spacing: 0) {
                    knowledgeHeader(for: client)
                    KnowledgeSummaryCard(client: client)
                }
                HealthConsentRow(
                    summary: snapshot.health, formatters: formatters, now: now,
                    action: { onOpen(.health(clientID: client.id)) }
                )
                VStack(alignment: .leading, spacing: 0) {
                    habitsHeader
                    HabitsCard(habits: snapshot.habits, source: client.source)
                }
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xl)
        }
        .refreshable { await viewModel.refreshAsync() }
        .accessibilityIdentifier("clientProfile.overview")
    }

    private func hasImportantNote(_ client: Client) -> Bool {
        client.importantNote != nil || !client.allergies.isEmpty
    }

    private func visitTiles(_ snapshot: ClientProfileSnapshot, now: Date) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.md))
            : AnyLayout(HStackLayout(spacing: Spacing.md))
        let next = snapshot.nextAppointment
        return layout {
            VisitTile(
                title: "clientProfile.lastVisit",
                service: snapshot.lastVisit?.serviceName,
                detail: snapshot.lastVisit.map { formatters.recentDate($0.startsAt, now: now) },
                emptyText: "clientProfile.lastVisit.empty", identifier: "clientProfile.lastVisit"
            )
            VisitTile(
                title: "clientProfile.next",
                service: next?.serviceName,
                detail: next.map {
                    formatters.dayAndTime(
                        $0.startsAt, now: now, today: String(localized: "clientProfile.today", locale: locale),
                        tomorrow: String(localized: "clientProfile.tomorrow", locale: locale)
                    )
                },
                emptyText: "clientProfile.next.empty",
                status: next.map { appointment in
                    appointment.status == .confirmed
                        ? .init(label: "clientProfile.next.confirmed", style: StatusPalette.confirmed)
                        : .init(label: "clientProfile.next.booked", style: StatusPalette.pending)
                },
                identifier: "clientProfile.next"
            )
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// The knowledge section's title with its Edit action. It is not a `SectionHeader` because that one carries no
    /// accessibility identifier on its action.
    private func knowledgeHeader(for client: Client) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("clientProfile.knowledge.title")
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.row)
            Button { onOpen(.knowledge(clientID: client.id)) } label: {
                Text("clientProfile.knowledge.edit")
                    .font(Typography.metaStrong)
                    .foregroundStyle(Palette.roseText)
                    .frame(minHeight: Spacing.touchTarget)
            }
            .accessibilityIdentifier("clientProfile.knowledgeEditButton")
        }
        .padding(.top, Spacing.section)
        .padding(.bottom, Spacing.row)
    }

    private var habitsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("clientProfile.habits.title")
                .font(Typography.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.row)
            Label { Text("clientProfile.habits.private") } icon: { Image(icon: .lock) }
                .font(Typography.footnote)
                .foregroundStyle(Palette.ink2)
        }
        .padding(.top, Spacing.section)
        .padding(.bottom, Spacing.row)
    }

    // MARK: - Helpers

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
