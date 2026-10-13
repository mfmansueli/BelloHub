//
//  MessageClientViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the message sheet (3.6): her quick replies, the one she picked filled in for this visit, and
/// the button that opens the chat. The app never sends by itself (D14): it opens WhatsApp (or Messages, or the share
/// sheet) with the text ready, and she presses send.
///
/// `{link}` is the client's own link to change or cancel when the visit came from her booking page (`ClientLinkService`
/// asks the server when the sheet opens, and again on Open if that failed), otherwise her booking page; `linkChoice`
/// says which, for the quiet line under the preview.
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
    /// The link `{link}` carries and why; nil until it is prepared.
    private(set) var linkChoice: ClientLinkChoice?
    /// The server is preparing the client's own link: Open waits for it.
    private(set) var isPreparingLink = false

    private let appointments: AppointmentService
    private let vault: VaultService
    private let profile: ProfileService
    private let setup: BookingSetupService
    private let messages: MessageService
    private let links: ClientLinkService
    private let now: @Sendable () -> Date

    init(
        appointmentID: UUID, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        setup: BookingSetupService, messages: MessageService, links: ClientLinkService,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.appointmentID = appointmentID
        self.appointments = appointments
        self.vault = vault
        self.profile = profile
        self.setup = setup
        self.messages = messages
        self.links = links
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

    /// The selected message has a link in it, so the sheet says which one.
    var showsLinkLine: Bool {
        selectedReply?.text.contains(QuickReplyVariable.link.token) == true
    }

    /// The text as it will open, filled in for this visit. Until the client's own link is ready it shows her booking
    /// page; Open waits for the link.
    var text: String? {
        guard let visit, let reply = selectedReply else { return nil }
        let link = linkChoice?.link ?? bookingPage?.messageText
        return AppointmentMessageComposer.text(
            for: .quickReply(reply),
            values: AppointmentMessageComposer.values(
                client: visit.client, appointment: visit.appointment, link: link, location: setup.setup.location,
                businessName: effectiveBusinessName
            ),
            localization: business.localization, formatters: business.messageFormatters
        )
    }

    private var effectiveBusinessName: String? {
        guard let currentProfile = profile.profile else { return nil }
        let name = currentProfile.businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let display = currentProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return display.isEmpty ? nil : display
    }

    private var bookingPage: BookingLink? {
        setup.setup.slug.map { BookingLink(slug: $0) }
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
            await prepareLink(for: loaded.appointment)
        } catch {
            isLoading = false
            errorMessage = String(interface: LocalizedStringResource("messageClient.error.load"))
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
        guard !isWorking, !isPreparingLink, let visit, let reply = selectedReply else { return }
        isWorking = true
        defer { isWorking = false }
        // The sheet opened offline or the server did not answer: one more try now that she is sending.
        if showsLinkLine, linkChoice?.canRetry == true { await prepareLink(for: visit.appointment) }
        guard let text else { return }
        outcome = await messages.send(
            text: text, to: visit.client.id, phoneE164: visit.client.phoneE164,
            template: AppointmentMessageKind.quickReply(reply).logTemplate, preferred: business.preferredChannel,
            now: now()
        )
        // The reminder (the "Confirm appointment" message) was opened: "Reminders ready" now shows it as opened (D31).
        if case .opened? = outcome, reply.builtInKey == BuiltInQuickReply.confirm.rawValue,
           visit.appointment.status.holdsTime {
            _ = try? await appointments.markReminderSent(id: visit.appointment.id, now: now())
        }
    }

    /// Asks for the client's own link (or settles on her booking page) for this visit.
    func prepareLink(for appointment: Appointment) async {
        guard !isPreparingLink else { return }
        isPreparingLink = true
        defer { isPreparingLink = false }
        linkChoice = await links.choice(for: appointment, bookingPage: bookingPage)
    }

    func dismissShare() {
        if case .needsShareSheet = outcome { outcome = nil }
    }
}
