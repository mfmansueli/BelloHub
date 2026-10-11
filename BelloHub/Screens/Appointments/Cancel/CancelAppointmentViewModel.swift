//
//  CancelAppointmentViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the cancel sheet (3.5): who cancels, what that means for the client, and the message to her.
/// The cancellation goes through `AppointmentService` with the policy this visit was made under (D47: for a visit made
/// by hand, today's policy); a message is opened only after the cancellation was saved.
@MainActor
@Observable
final class CancelAppointmentViewModel {
    /// How the sheet ended once she confirmed.
    struct Done: Equatable {
        /// Nil when she chose not to send a message.
        let message: MessageService.Outcome?
    }

    let appointmentID: UUID
    private(set) var visit: VisitContext?
    private(set) var business: AgendaBusinessContext
    private(set) var isLoading = true
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    private(set) var actionErrorMessage: String?
    private(set) var isWorking = false
    private(set) var done: Done?
    var cancelledBy = CancelledBy.professional
    /// Only a cancellation by her has a message: when the client cancelled, there is nothing to apologise for.
    var sendsMessage = true

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

    /// Only a visit that still holds its time can be cancelled.
    var canCancel: Bool {
        visit?.appointment.status.holdsTime ?? false
    }

    var offersMessage: Bool {
        cancelledBy == .professional
    }

    var notice: CancelNotice? {
        visit.map {
            CancelNotice.make(
                by: cancelledBy, policy: setup.setup.cancellation, noShow: setup.setup.noShow,
                startsAt: $0.appointment.startsAt, now: now()
            )
        }
    }

    // MARK: - Actions

    /// Fire-and-forget entry point for the retry button.
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
            if !setup.hasLoaded { try? await setup.load(timeZoneID: business.timeZone.identifier) }
            visit = loaded
            errorMessage = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = String(interface: LocalizedStringResource("cancelAppointment.error.load"))
        }
    }

    func confirm() {
        Task { await confirmAsync() }
    }

    func confirmAsync() async {
        guard !isWorking, canCancel, let visit else { return }
        isWorking = true
        defer { isWorking = false }
        let moment = now()
        do {
            let changed = try await appointments.cancel(
                id: appointmentID, by: cancelledBy, policy: setup.setup.cancellation, now: moment
            )
            self.visit = VisitContext(appointment: changed, client: visit.client)
        } catch {
            actionErrorMessage = String(interface: LocalizedStringResource("cancelAppointment.error.save"))
            return
        }
        actionErrorMessage = nil
        var outcome: MessageService.Outcome?
        if offersMessage, sendsMessage {
            outcome = await messages.send(
                text: messageText(for: visit), to: visit.client.id, phoneE164: visit.client.phoneE164,
                template: AppointmentMessageKind.cancelled.logTemplate, preferred: business.preferredChannel,
                now: moment
            )
        }
        done = Done(message: outcome)
    }

    func dismissActionError() {
        actionErrorMessage = nil
    }

    // MARK: - Message

    /// The text she is about to open, shown before she confirms.
    var messagePreview: String? {
        visit.map(messageText(for:))
    }

    private func messageText(for visit: VisitContext) -> String {
        let link = setup.setup.slug.map { BookingLink(slug: $0).display }
        return AppointmentMessageComposer.text(
            for: .cancelled,
            values: AppointmentMessageComposer.values(client: visit.client, appointment: visit.appointment, link: link),
            localization: business.localization, formatters: business.messageFormatters
        )
    }
}
