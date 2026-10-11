//
//  RunningLateViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the running-late sheet (2.12). She says how late she will be and writes to the clients who are
/// waiting: this visit's client and the ones after her today, one chat each (WhatsApp opens for one person at a time).
/// The calendar does not change.
@MainActor
@Observable
final class RunningLateViewModel {
    /// A client to tell.
    struct Recipient: Identifiable, Equatable, Sendable {
        let appointment: Appointment
        let client: Client

        var id: UUID { appointment.id }
    }

    let appointmentID: UUID
    private(set) var recipients: [Recipient] = []
    private(set) var business: AgendaBusinessContext
    private(set) var isLoading = true
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    private(set) var isWorking = false
    /// The visits whose chat she has already opened.
    private(set) var opened: Set<UUID> = []
    /// A client the share sheet has to deliver to, because neither WhatsApp nor Messages could open.
    private(set) var share: SharePayload?
    var delay = RunningLateRules.defaultDelay

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

    var showsLongWaitHint: Bool {
        RunningLateRules.isLongWait(delay)
    }

    // MARK: - Actions

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        business = AgendaBusinessContext(profile: profile.profile)
        let reader = VisitReader(appointments: appointments, vault: vault)
        do {
            guard let anchor = try await reader.visit(id: appointmentID) else {
                isMissing = true
                isLoading = false
                return
            }
            let calendar = business.calendar
            let day = calendar.dateInterval(of: .day, for: anchor.appointment.startsAt)
                ?? DateInterval(start: anchor.appointment.startsAt, duration: 86_400)
            let sameDay = try await appointments.appointments(in: day)
            let chosen = RunningLateRules.recipients(
                startingWith: anchor.appointment, among: sameDay, calendar: calendar
            )
            guard let repository = vault.repository else { throw VaultRepositoryError.unavailable }
            var list: [Recipient] = []
            for appointment in chosen {
                if let client = try await repository.client(id: appointment.clientID) {
                    list.append(Recipient(appointment: appointment, client: client))
                }
            }
            recipients = list
            errorMessage = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = String(interface: LocalizedStringResource("runningLate.error.load"))
        }
    }

    /// Opens the chat for one client with the message ready.
    func tell(_ recipient: Recipient) {
        Task { await tellAsync(recipient) }
    }

    func tellAsync(_ recipient: Recipient) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let kind = AppointmentMessageKind.runningLate(minutes: delay)
        let values = AppointmentMessageComposer.values(
            client: recipient.client, appointment: recipient.appointment, link: nil
        )
        let text = AppointmentMessageComposer.text(
            for: kind, values: values, localization: business.localization, formatters: business.messageFormatters
        )
        let outcome = await messages.send(
            text: text, to: recipient.client.id, phoneE164: recipient.client.phoneE164, template: kind.logTemplate,
            preferred: business.preferredChannel, now: now()
        )
        opened.insert(recipient.id)
        if case .needsShareSheet(let shared) = outcome { share = SharePayload(text: shared) }
    }

    func dismissShare() {
        share = nil
    }
}
