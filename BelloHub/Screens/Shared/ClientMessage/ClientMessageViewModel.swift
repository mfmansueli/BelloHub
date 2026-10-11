//
//  ClientMessageViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the client message sheet (follow-up, win back, birthday): the client, the text ready for her to
/// read and edit, and the button that opens the chat. The app never sends by itself (D14): it opens WhatsApp (or
/// Messages, or the share sheet) with the text, and she presses send.
@MainActor
@Observable
final class ClientMessageViewModel {
    let request: ClientMessageRequest
    private(set) var client: Client?
    private(set) var business: AgendaBusinessContext
    /// The message as she will send it. Filled once from the wording; what she types replaces it.
    var draft = ""
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
        request: ClientMessageRequest, appointments: AppointmentService, vault: VaultService, profile: ProfileService,
        setup: BookingSetupService, messages: MessageService, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.request = request
        self.appointments = appointments
        self.vault = vault
        self.profile = profile
        self.setup = setup
        self.messages = messages
        self.now = now
        business = AgendaBusinessContext(profile: profile.profile)
    }

    // MARK: - Derived

    /// The client has a number WhatsApp or Messages can open. Without one only the share sheet is left.
    var hasNumber: Bool {
        MessageLinks.digits(ofE164: client?.phoneE164) != nil
    }

    var canOpen: Bool {
        !isWorking && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        business = AgendaBusinessContext(profile: profile.profile)
        guard let repository = vault.repository else {
            errorMessage = String(interface: LocalizedStringResource("messageClient.error.load"))
            isLoading = false
            return
        }
        do {
            guard let loaded = try await repository.client(id: request.clientID) else {
                isMissing = true
                isLoading = false
                return
            }
            try await setup.loadQuickReplies(localization: business.localization)
            if !setup.hasLoaded { try? await setup.load(timeZoneID: business.timeZone.identifier) }
            let history = (try? await appointments.appointments(for: loaded.id)) ?? []
            client = loaded
            if draft.isEmpty { draft = text(for: loaded, history: history) }
            errorMessage = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = String(interface: LocalizedStringResource("messageClient.error.load"))
        }
    }

    func open() {
        Task { await openAsync() }
    }

    func openAsync() async {
        guard canOpen, let client else { return }
        isWorking = true
        defer { isWorking = false }
        outcome = await messages.send(
            text: draft, to: client.id, phoneE164: client.phoneE164, template: request.logTemplate,
            preferred: business.preferredChannel, now: now()
        )
    }

    // MARK: - Private

    private func text(for client: Client, history: [Appointment]) -> String {
        let comeBack = setup.quickReplies.first { $0.builtInKey == BuiltInQuickReply.comeBack.rawValue }
        let link = setup.setup.slug.map { BookingLink(slug: $0).display }
        let values = ClientMessageComposer.values(
            for: request.kind, client: client, lastServiceName: ClientMessageComposer.lastServiceName(in: history),
            link: link
        )
        return ClientMessageComposer.text(
            for: request.kind, comeBack: comeBack, values: values, localization: business.localization,
            formatters: business.messageFormatters
        )
    }
}
