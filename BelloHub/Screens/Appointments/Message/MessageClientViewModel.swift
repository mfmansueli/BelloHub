//
//  MessageClientViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the message sheet (3.6): her quick replies, the one she picked filled in for this visit, and
/// the button that opens the chat. The app never sends by itself (D14): it opens WhatsApp (or Messages, or the share
/// sheet) with the text ready, and she presses send.
@MainActor
@Observable
final class MessageClientViewModel {
    let appointmentID: UUID
    private(set) var visit: VisitContext?
    private(set) var business: AgendaBusinessContext
    private(set) var replies: [QuickReply] = []
    private(set) var selectedID: UUID?
    private(set) var isLoading = true
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    private(set) var isWorking = false
    /// How the last "Open" ended; nil before she presses it.
    private(set) var outcome: MessageService.Outcome?

    private let appointments: AppointmentService
    private let vault: VaultService
    private let profile: ProfileService
    private let setup: BookingSetupService
    private let messages: MessageService
    private let now: @Sendable () -> Date

    init(
        appointmentID: UUID, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        setup: BookingSetupService, messages: MessageService, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.appointmentID = appointmentID
        self.appointments = appointments
        self.vault = vault
        self.profile = profile
        self.setup = setup
        self.messages = messages
        self.now = now
        business = AgendaBusinessContext(profile: profile.profile)
    }

    // MARK: - Derived

    var selectedReply: QuickReply? {
        replies.first { $0.id == selectedID }
    }

    /// The client has a number WhatsApp or Messages can open. Without one only the share sheet is left.
    var hasNumber: Bool {
        MessageLinks.digits(ofE164: visit?.client.phoneE164) != nil
    }

    /// The text as it will open, filled in for this visit.
    var text: String? {
        guard let visit, let reply = selectedReply else { return nil }
        let link = setup.setup.slug.map { BookingLink(slug: $0).display }
        return AppointmentMessageComposer.text(
            for: .quickReply(reply),
            values: AppointmentMessageComposer.values(client: visit.client, appointment: visit.appointment, link: link),
            localization: business.localization, formatters: business.messageFormatters
        )
    }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        business = AgendaBusinessContext(profile: profile.profile)
        do {
            guard let loaded = try await VisitReader(appointments: appointments, vault: vault).visit(id: appointmentID)
            else {
                isMissing = true
                isLoading = false
                return
            }
            try await setup.loadQuickReplies(localization: business.localization)
            if !setup.hasLoaded { try? await setup.load(timeZoneID: business.timeZone.identifier) }
            visit = loaded
            replies = setup.quickReplies
            if selectedID == nil || selectedReply == nil {
                selectedID = MessageSuggestion.reply(for: loaded.appointment, among: replies, now: now())?.id
            }
            errorMessage = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = String(localized: "messageClient.error.load")
        }
    }

    func select(_ reply: QuickReply) {
        selectedID = reply.id
        outcome = nil
    }

    func open() {
        Task { await openAsync() }
    }

    func openAsync() async {
        guard !isWorking, let visit, let reply = selectedReply, let text else { return }
        isWorking = true
        defer { isWorking = false }
        outcome = await messages.send(
            text: text, to: visit.client.id, phoneE164: visit.client.phoneE164,
            template: AppointmentMessageKind.quickReply(reply).logTemplate, preferred: business.preferredChannel,
            now: now()
        )
    }

    func dismissShare() {
        if case .needsShareSheet = outcome { outcome = nil }
    }
}
